
-- Fix workspace creation issues

-- First, ensure RLS is enabled on all tables
ALTER TABLE IF EXISTS public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.page_shares ENABLE ROW LEVEL SECURITY;

-- Drop existing policies on workspaces to avoid conflicts
DROP POLICY IF EXISTS "users_can_view_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_insert_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_update_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_delete_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "members_can_view_workspaces" ON public.workspaces;

-- Create more permissive policies for workspace creation
CREATE POLICY "allow_users_to_create_workspaces"
ON public.workspaces
FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Policy for users to view their own workspaces
CREATE POLICY "users_can_view_own_workspaces"
ON public.workspaces
FOR SELECT
USING (owner_id = auth.uid());

-- Policy for users to view workspaces they are members of
CREATE POLICY "members_can_view_workspaces"
ON public.workspaces
FOR SELECT
USING (
  id IN (
    SELECT workspace_id 
    FROM public.workspace_members 
    WHERE user_id = auth.uid()
  )
);

-- Policy for users to update their own workspaces
CREATE POLICY "users_can_update_own_workspaces"
ON public.workspaces
FOR UPDATE
USING (owner_id = auth.uid());

-- Policy for users to delete their own workspaces
CREATE POLICY "users_can_delete_own_workspaces"
ON public.workspaces
FOR DELETE
USING (owner_id = auth.uid());

-- Fix workspace_members policies
DROP POLICY IF EXISTS "users_can_view_workspace_members" ON public.workspace_members;
DROP POLICY IF EXISTS "workspace_owners_can_manage_members" ON public.workspace_members;

-- Allow users to create workspace_members records
CREATE POLICY "allow_users_to_create_workspace_members"
ON public.workspace_members
FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL AND (
    -- User can add themselves to a workspace they own
    user_id = auth.uid() AND 
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  )
);

-- Allow users to view workspace members
CREATE POLICY "users_can_view_workspace_members"
ON public.workspace_members
FOR SELECT
USING (
  user_id = auth.uid() OR 
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

-- Allow workspace owners to manage members
CREATE POLICY "workspace_owners_can_manage_members"
ON public.workspace_members
USING (
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
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
  
  -- Directly insert the workspace_member record
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (workspace_id, NEW.id, 'owner')
  ON CONFLICT (workspace_id, user_id) DO NOTHING;
  
  -- Create a default welcome page
  INSERT INTO public.pages (title, content, workspace_id, created_by, position, is_favorite)
  VALUES (
    'Welcome to your workspace',
    '{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Welcome to your new workspace!"}]},{"type":"paragraph","content":[{"type":"text","text":"This is your first page. You can edit it or create new pages using the sidebar."}]}]}',
    workspace_id,
    NEW.id,
    0,
    false
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Add default values to tables to prevent null value errors
ALTER TABLE public.pages ALTER COLUMN is_favorite SET DEFAULT false;
ALTER TABLE public.pages ALTER COLUMN position SET DEFAULT 0;