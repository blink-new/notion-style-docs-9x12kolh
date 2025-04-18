
-- Add policy for workspace members to view workspaces they are members of

-- Create a policy that allows members to view workspaces they belong to
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

-- Fix pages policies to ensure proper access
DROP POLICY IF EXISTS "Workspace owners can do everything with pages" ON public.pages;
DROP POLICY IF EXISTS "Workspace members can view pages" ON public.pages;

-- Create simplified policies for pages
CREATE POLICY "workspace_owners_can_manage_pages"
ON public.pages
USING (
  workspace_id IN (
    SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_members_can_view_pages"
ON public.pages
FOR SELECT
USING (
  workspace_id IN (
    SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid()
  )
);

-- Add policy for workspace members to edit pages
CREATE POLICY "workspace_members_can_edit_pages"
ON public.pages
FOR UPDATE
USING (
  workspace_id IN (
    SELECT workspace_id FROM public.workspace_members 
    WHERE user_id = auth.uid() AND role IN ('owner', 'editor')
  )
);

-- Fix page_shares policies
DROP POLICY IF EXISTS "Workspace owners can manage page shares" ON public.page_shares;
DROP POLICY IF EXISTS "Anyone can view page shares" ON public.page_shares;

CREATE POLICY "workspace_owners_can_manage_page_shares"
ON public.page_shares
USING (
  page_id IN (
    SELECT id FROM public.pages 
    WHERE workspace_id IN (
      SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
    )
  )
);

CREATE POLICY "anyone_can_view_page_shares"
ON public.page_shares
FOR SELECT
USING (true);