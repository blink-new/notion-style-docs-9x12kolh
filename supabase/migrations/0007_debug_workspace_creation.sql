
-- Debug and fix workspace creation issues

-- First, check and fix table constraints
ALTER TABLE IF EXISTS public.workspaces 
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE IF EXISTS public.workspace_members 
  ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE IF EXISTS public.pages 
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET DEFAULT now(),
  ALTER COLUMN is_favorite SET DEFAULT false,
  ALTER COLUMN position SET DEFAULT 0;

-- Create a more robust function for workspace creation
CREATE OR REPLACE FUNCTION create_workspace_with_member(
  p_name TEXT,
  p_owner_id UUID
) RETURNS UUID AS $$
DECLARE
  v_workspace_id UUID;
BEGIN
  -- Insert the workspace
  INSERT INTO public.workspaces (name, owner_id)
  VALUES (p_name, p_owner_id)
  RETURNING id INTO v_workspace_id;
  
  -- Insert the workspace member
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (v_workspace_id, p_owner_id, 'owner');
  
  RETURN v_workspace_id;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error creating workspace: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to create a default page
CREATE OR REPLACE FUNCTION create_default_page(
  p_workspace_id UUID,
  p_user_id UUID,
  p_title TEXT DEFAULT 'Welcome to your workspace',
  p_content JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_page_id UUID;
  v_content JSONB;
BEGIN
  -- Set default content if not provided
  IF p_content IS NULL THEN
    v_content := '{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Welcome to your new workspace!"}]},{"type":"paragraph","content":[{"type":"text","text":"This is your first page. You can edit it or create new pages using the sidebar."}]}]}';
  ELSE
    v_content := p_content;
  END IF;

  -- Insert the page
  INSERT INTO public.pages (
    title, 
    content, 
    workspace_id, 
    created_by, 
    position, 
    is_favorite
  )
  VALUES (
    p_title,
    v_content,
    p_workspace_id,
    p_user_id,
    0,
    false
  )
  RETURNING id INTO v_page_id;
  
  RETURN v_page_id;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error creating page: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to initialize a new user with workspace and page
CREATE OR REPLACE FUNCTION initialize_new_user(
  p_user_id UUID,
  p_workspace_name TEXT DEFAULT 'My Workspace'
) RETURNS UUID AS $$
DECLARE
  v_workspace_id UUID;
BEGIN
  -- Create workspace with member
  v_workspace_id := create_workspace_with_member(p_workspace_name, p_user_id);
  
  -- Create default page
  PERFORM create_default_page(v_workspace_id, p_user_id);
  
  RETURN v_workspace_id;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error initializing user: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Completely recreate the handle_new_user function and trigger
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert the user record
  INSERT INTO public.users (id, email, display_name)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  
  -- Initialize the user with workspace and page
  PERFORM initialize_new_user(NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Recreate RLS policies with more permissive rules
-- First drop existing policies
DROP POLICY IF EXISTS "allow_users_to_create_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_view_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "members_can_view_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_update_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_delete_own_workspaces" ON public.workspaces;

-- Create new policies
-- Allow all authenticated users to create workspaces
CREATE POLICY "allow_all_authenticated_users_to_create_workspaces"
ON public.workspaces
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow users to view workspaces they own
CREATE POLICY "users_can_view_own_workspaces"
ON public.workspaces
FOR SELECT
TO authenticated
USING (owner_id = auth.uid() OR id IN (
  SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid()
));

-- Allow users to update workspaces they own
CREATE POLICY "users_can_update_own_workspaces"
ON public.workspaces
FOR UPDATE
TO authenticated
USING (owner_id = auth.uid());

-- Allow users to delete workspaces they own
CREATE POLICY "users_can_delete_own_workspaces"
ON public.workspaces
FOR DELETE
TO authenticated
USING (owner_id = auth.uid());

-- Workspace members policies
DROP POLICY IF EXISTS "allow_users_to_create_workspace_members" ON public.workspace_members;
DROP POLICY IF EXISTS "users_can_view_workspace_members" ON public.workspace_members;
DROP POLICY IF EXISTS "workspace_owners_can_manage_members" ON public.workspace_members;

-- Allow all authenticated users to create workspace members
CREATE POLICY "allow_all_authenticated_users_to_create_workspace_members"
ON public.workspace_members
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow users to view workspace members they are part of
CREATE POLICY "users_can_view_workspace_members"
ON public.workspace_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR 
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

-- Pages policies
DROP POLICY IF EXISTS "users_can_create_pages" ON public.pages;
DROP POLICY IF EXISTS "users_can_view_pages" ON public.pages;
DROP POLICY IF EXISTS "users_can_update_pages" ON public.pages;
DROP POLICY IF EXISTS "users_can_delete_pages" ON public.pages;

-- Allow all authenticated users to create pages
CREATE POLICY "allow_all_authenticated_users_to_create_pages"
ON public.pages
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow users to view pages in workspaces they are members of
CREATE POLICY "users_can_view_pages"
ON public.pages
FOR SELECT
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
    UNION
    SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid()
  )
);

-- Allow users to update pages in workspaces they are members of
CREATE POLICY "users_can_update_pages"
ON public.pages
FOR UPDATE
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
    UNION
    SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid()
  )
);

-- Allow users to delete pages in workspaces they are members of
CREATE POLICY "users_can_delete_pages"
ON public.pages
FOR DELETE
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
    UNION
    SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid()
  )
);