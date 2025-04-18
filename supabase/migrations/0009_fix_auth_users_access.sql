
-- Fix auth.users access and workspace creation issues

-- Create a secure function to get user details from auth.users
CREATE OR REPLACE FUNCTION get_auth_user_details(p_user_id UUID)
RETURNS TABLE (
  email TEXT,
  display_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.email,
    COALESCE(u.raw_user_meta_data->>'name', split_part(u.email, '@', 1)) as display_name
  FROM auth.users u
  WHERE u.id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the ensure_user_exists function to use the secure function
CREATE OR REPLACE FUNCTION ensure_user_exists(
  p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_user_exists BOOLEAN;
  v_user_email TEXT;
  v_user_display_name TEXT;
BEGIN
  -- Check if user exists in public.users
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  -- Create user record if it doesn't exist
  IF NOT v_user_exists THEN
    -- Get user info from auth.users using the secure function
    SELECT email, display_name 
    INTO v_user_email, v_user_display_name
    FROM get_auth_user_details(p_user_id);
    
    IF v_user_email IS NULL THEN
      RETURN FALSE;
    END IF;
    
    INSERT INTO public.users (id, email, display_name)
    VALUES (
      p_user_id, 
      v_user_email, 
      v_user_display_name
    );
  END IF;
  
  RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error ensuring user exists: %', SQLERRM;
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the initialize_new_user function to use the secure function
CREATE OR REPLACE FUNCTION initialize_new_user(
  p_user_id UUID,
  p_workspace_name TEXT DEFAULT 'My Workspace'
) RETURNS UUID AS $$
DECLARE
  v_workspace_id UUID;
  v_user_exists BOOLEAN;
  v_user_email TEXT;
  v_user_display_name TEXT;
BEGIN
  -- Check if user exists in auth.users using the secure function
  SELECT email, display_name 
  INTO v_user_email, v_user_display_name
  FROM get_auth_user_details(p_user_id);
  
  IF v_user_email IS NULL THEN
    RAISE EXCEPTION 'User not found in auth.users';
  END IF;
  
  -- Check if user exists in public.users
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  -- Create user record if it doesn't exist
  IF NOT v_user_exists THEN
    INSERT INTO public.users (id, email, display_name)
    VALUES (
      p_user_id, 
      v_user_email, 
      v_user_display_name
    );
  END IF;
  
  -- Create workspace with member
  v_workspace_id := create_workspace_with_member(p_workspace_name, p_user_id);
  
  -- Create default page
  PERFORM create_default_page(v_workspace_id, p_user_id);
  
  RETURN v_workspace_id;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error initializing user: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the create_workspace_with_member function to use the secure function
CREATE OR REPLACE FUNCTION create_workspace_with_member(
  p_name TEXT,
  p_owner_id UUID
) RETURNS UUID AS $$
DECLARE
  v_workspace_id UUID;
  v_user_exists BOOLEAN;
  v_user_email TEXT;
  v_user_display_name TEXT;
BEGIN
  -- Check if user exists in public.users
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_owner_id) INTO v_user_exists;
  
  -- Create user record if it doesn't exist
  IF NOT v_user_exists THEN
    -- Get user info from auth.users using the secure function
    SELECT email, display_name 
    INTO v_user_email, v_user_display_name
    FROM get_auth_user_details(p_owner_id);
    
    IF v_user_email IS NULL THEN
      RAISE EXCEPTION 'User not found in auth.users';
    END IF;
    
    INSERT INTO public.users (id, email, display_name)
    VALUES (
      p_owner_id, 
      v_user_email, 
      v_user_display_name
    );
  END IF;
  
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

-- Update the handle_new_user function to use the secure function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_workspace_id UUID;
  v_user_email TEXT;
  v_user_display_name TEXT;
BEGIN
  -- Get user details using the secure function
  SELECT email, display_name 
  INTO v_user_email, v_user_display_name
  FROM get_auth_user_details(NEW.id);
  
  -- Insert the user record
  INSERT INTO public.users (id, email, display_name)
  VALUES (
    NEW.id, 
    v_user_email, 
    v_user_display_name
  )
  ON CONFLICT (id) DO NOTHING;
  
  -- Initialize the user with workspace and page
  v_workspace_id := initialize_new_user(NEW.id);
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error in handle_new_user: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get user profile by ID
CREATE OR REPLACE FUNCTION get_user_profile(p_user_id UUID)
RETURNS SETOF public.users AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.users WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get auth user email by ID
CREATE OR REPLACE FUNCTION get_auth_user_email(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_email TEXT;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = p_user_id;
  RETURN v_email;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get auth user metadata by ID
CREATE OR REPLACE FUNCTION get_auth_user_metadata(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_metadata JSONB;
BEGIN
  SELECT raw_user_meta_data INTO v_metadata FROM auth.users WHERE id = p_user_id;
  RETURN v_metadata;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a more permissive policy for users table
DROP POLICY IF EXISTS "users_can_view_own_profile" ON public.users;
DROP POLICY IF EXISTS "users_can_update_own_profile" ON public.users;
DROP POLICY IF EXISTS "users_can_view_workspace_members_profiles" ON public.users;

CREATE POLICY "allow_all_authenticated_users_to_view_users"
ON public.users
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "users_can_update_own_profile"
ON public.users
FOR UPDATE
TO authenticated
USING (id = auth.uid());

-- Create a more permissive policy for workspaces table
DROP POLICY IF EXISTS "users_can_view_own_workspaces" ON public.workspaces;
DROP POLICY IF EXISTS "allow_all_authenticated_users_to_create_workspaces" ON public.workspaces;

CREATE POLICY "allow_all_authenticated_users_to_view_workspaces"
ON public.workspaces
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "allow_all_authenticated_users_to_create_workspaces"
ON public.workspaces
FOR INSERT
TO authenticated
WITH CHECK (true);