
-- Fix infinite loading issues by simplifying database access

-- Create a more permissive policy for workspaces
DROP POLICY IF EXISTS "allow_all_authenticated_users_to_view_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "allow_all_authenticated_users_to_create_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_view_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "members_can_view_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_update_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "users_can_delete_own_workspaces" ON public.workspaces;

-- Create simplified policies for workspaces
CREATE POLICY "authenticated_users_can_select_workspaces"
ON public.workspaces
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "authenticated_users_can_insert_workspaces"
ON public.workspaces
FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

CREATE POLICY "authenticated_users_can_update_own_workspaces"
ON public.workspaces
FOR UPDATE
TO authenticated
USING (owner_id = auth.uid());

CREATE POLICY "authenticated_users_can_delete_own_workspaces"
ON public.workspaces
FOR DELETE
TO authenticated
USING (owner_id = auth.uid());

-- Create simplified policies for workspace_members
DROP POLICY IF EXISTS "allow_all_authenticated_users_to_create_workspace_members" ON public.workspace_members;
DROP POLICY IF EXISTS "users_can_view_workspace_members" ON public.workspace_members;
DROP POLICY IF EXISTS "workspace_owners_can_manage_members" ON public.workspace_members;
DROP POLICY IF EXISTS "allow_users_to_create_workspace_members" ON public.workspace_members;

CREATE POLICY "authenticated_users_can_select_workspace_members"
ON public.workspace_members
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "authenticated_users_can_insert_workspace_members"
ON public.workspace_members
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() OR
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "authenticated_users_can_update_workspace_members"
ON public.workspace_members
FOR UPDATE
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "authenticated_users_can_delete_workspace_members"
ON public.workspace_members
FOR DELETE
TO authenticated
USING (
  user_id = auth.uid() OR
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

-- Create simplified policies for pages
DROP POLICY IF EXISTS "allow_all_authenticated_users_to_create_pages" ON public.pages;
DROP POLICY IF EXISTS "users_can_view_pages" ON public.pages;
DROP POLICY IF EXISTS "users_can_update_pages" ON public.pages;
DROP POLICY IF EXISTS "users_can_delete_pages" ON public.pages;
DROP POLICY IF EXISTS "workspace_owners_can_manage_pages" ON public.pages;
DROP POLICY IF EXISTS "workspace_members_can_view_pages" ON public.pages;
DROP POLICY IF EXISTS "workspace_members_can_edit_pages" ON public.pages;

CREATE POLICY "authenticated_users_can_select_pages"
ON public.pages
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "authenticated_users_can_insert_pages"
ON public.pages
FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());

CREATE POLICY "authenticated_users_can_update_pages"
ON public.pages
FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid() OR
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  ) OR
  workspace_id IN (
    SELECT workspace_id FROM public.workspace_members 
    WHERE user_id = auth.uid() AND role IN ('owner', 'editor')
  )
);

CREATE POLICY "authenticated_users_can_delete_pages"
ON public.pages
FOR DELETE
TO authenticated
USING (
  created_by = auth.uid() OR
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

-- Create simplified policies for users
DROP POLICY IF EXISTS "allow_all_authenticated_users_to_view_users" ON public.users;
DROP POLICY IF EXISTS "users_can_update_own_profile" ON public.users;

CREATE POLICY "authenticated_users_can_select_users"
ON public.users
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "authenticated_users_can_update_own_profile"
ON public.users
FOR UPDATE
TO authenticated
USING (id = auth.uid());

CREATE POLICY "authenticated_users_can_insert_users"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());