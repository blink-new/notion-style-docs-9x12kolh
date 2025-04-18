
-- Fix infinite recursion in workspaces policy

-- First, drop all existing policies on the workspaces table to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "Users can create their own workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "Users can update their own workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "Users can delete their own workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "Workspace members can view workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "Workspace owners can do everything" ON public.workspaces;
DROP POLICY IF EXISTS "Workspace members can view workspaces" ON public.workspaces;

-- Create simplified policies that avoid recursion
-- Owner policy - allows full access to workspaces owned by the user
CREATE POLICY "workspace_owner_policy" 
ON public.workspaces
USING (owner_id = auth.uid());

-- Member policy - allows SELECT only for members
-- This avoids the recursive lookup that was causing the infinite recursion
CREATE POLICY "workspace_member_policy" 
ON public.workspaces 
FOR SELECT
USING (
  id IN (
    SELECT workspace_id 
    FROM public.workspace_members 
    WHERE user_id = auth.uid()
  )
);

-- Fix the handle_new_user function to be more robust
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  workspace_id UUID;
BEGIN
  -- Insert the user record
  INSERT INTO public.users (id, email, display_name)
  VALUES (NEW.id, NEW.email, split_part(NEW.email, '@', 1))
  ON CONFLICT (id) DO NOTHING;
  
  -- Create a default workspace for new users
  INSERT INTO public.workspaces (name, owner_id)
  VALUES ('My Workspace', NEW.id)
  RETURNING id INTO workspace_id;
  
  -- Directly insert the workspace_member record instead of relying on the trigger
  -- This avoids potential circular dependencies
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (workspace_id, NEW.id, 'owner')
  ON CONFLICT (workspace_id, user_id) DO NOTHING;
  
  -- Create a default welcome page
  INSERT INTO public.pages (title, content, workspace_id, created_by)
  VALUES (
    'Welcome to your workspace',
    '{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Welcome to your new workspace!"}]},{"type":"paragraph","content":[{"type":"text","text":"This is your first page. You can edit it or create new pages using the sidebar."}]}]}',
    workspace_id,
    NEW.id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the add_workspace_owner_as_member trigger to avoid circular dependencies
DROP TRIGGER IF EXISTS on_workspace_created ON public.workspaces;