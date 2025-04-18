
-- Fix RLS policies for the workspaces table

-- First, drop the existing policies on the workspaces table
DROP POLICY IF EXISTS "Workspace owners can do everything" ON public.workspaces;
DROP POLICY IF EXISTS "Workspace members can view workspaces" ON public.workspaces;

-- Create more permissive policies for the workspaces table
-- Allow users to select their own workspaces (where they are the owner)
CREATE POLICY "Users can view their own workspaces"
  ON public.workspaces FOR SELECT
  USING (owner_id = auth.uid());

-- Allow users to insert their own workspaces
CREATE POLICY "Users can create their own workspaces"
  ON public.workspaces FOR INSERT
  WITH CHECK (owner_id = auth.uid());

-- Allow users to update their own workspaces
CREATE POLICY "Users can update their own workspaces"
  ON public.workspaces FOR UPDATE
  USING (owner_id = auth.uid());

-- Allow users to delete their own workspaces
CREATE POLICY "Users can delete their own workspaces"
  ON public.workspaces FOR DELETE
  USING (owner_id = auth.uid());

-- Allow users to view workspaces where they are members
CREATE POLICY "Workspace members can view workspaces"
  ON public.workspaces FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members
      WHERE workspace_members.workspace_id = workspaces.id
      AND workspace_members.user_id = auth.uid()
    )
  );

-- Fix the handle_new_user function to ensure it works properly
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert the user record
  INSERT INTO public.users (id, email, display_name)
  VALUES (NEW.id, NEW.email, split_part(NEW.email, '@', 1))
  ON CONFLICT (id) DO NOTHING;
  
  -- Create a default workspace for new users
  INSERT INTO public.workspaces (name, owner_id)
  VALUES ('My Workspace', NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Fix the add_workspace_owner_as_member function
CREATE OR REPLACE FUNCTION add_workspace_owner_as_member()
RETURNS TRIGGER AS $$
BEGIN
  -- Add the owner as a member with 'owner' role
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner')
  ON CONFLICT (workspace_id, user_id) DO NOTHING;
  
  -- Create a default welcome page
  INSERT INTO public.pages (title, content, workspace_id, created_by)
  VALUES (
    'Welcome to your workspace',
    '{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Welcome to your new workspace!"}]},{"type":"paragraph","content":[{"type":"text","text":"This is your first page. You can edit it or create new pages using the sidebar."}]}]}',
    NEW.id,
    NEW.owner_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS on_workspace_created ON public.workspaces;
CREATE TRIGGER on_workspace_created
AFTER INSERT ON public.workspaces
FOR EACH ROW EXECUTE FUNCTION add_workspace_owner_as_member();