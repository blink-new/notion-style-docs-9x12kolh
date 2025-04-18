
-- Fix workspace access issues and RLS policies

-- First, drop all existing policies on the workspaces table to avoid conflicts
DROP POLICY IF EXISTS "workspace_owner_policy" ON public.workspaces;
DROP POLICY IF EXISTS "workspace_member_policy" ON public.workspaces;

-- Create a simple, direct policy for workspace access
-- This policy allows users to view workspaces they own
CREATE POLICY "users_can_view_own_workspaces" 
ON public.workspaces 
FOR SELECT
USING (owner_id = auth.uid());

-- This policy allows users to insert their own workspaces
CREATE POLICY "users_can_insert_own_workspaces" 
ON public.workspaces 
FOR INSERT
WITH CHECK (owner_id = auth.uid());

-- This policy allows users to update their own workspaces
CREATE POLICY "users_can_update_own_workspaces" 
ON public.workspaces 
FOR UPDATE
USING (owner_id = auth.uid());

-- This policy allows users to delete their own workspaces
CREATE POLICY "users_can_delete_own_workspaces" 
ON public.workspaces 
FOR DELETE
USING (owner_id = auth.uid());

-- Fix the workspace_members policy to avoid recursion
DROP POLICY IF EXISTS "Workspace owners can manage members" ON public.workspace_members;
DROP POLICY IF EXISTS "Users can view workspace members" ON public.workspace_members;

-- Create simplified policies for workspace_members
CREATE POLICY "users_can_view_workspace_members"
ON public.workspace_members
FOR SELECT
USING (
  user_id = auth.uid() OR 
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_owners_can_manage_members"
ON public.workspace_members
USING (
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

-- Fix the users table policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;

CREATE POLICY "users_can_view_own_profile"
ON public.users
FOR SELECT
USING (id = auth.uid());

CREATE POLICY "users_can_update_own_profile"
ON public.users
FOR UPDATE
USING (id = auth.uid());

-- Add a policy to allow users to see other users in their workspaces
CREATE POLICY "users_can_view_workspace_members_profiles"
ON public.users
FOR SELECT
USING (
  id IN (
    SELECT user_id FROM public.workspace_members
    WHERE workspace_id IN (
      SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid()
    )
  )
);

-- Ensure the handle_new_user function is properly defined
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
  
  -- Directly insert the workspace_member record
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

-- Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();