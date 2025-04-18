
-- Fix foreign key constraint issue by ensuring user record exists before workspace creation

-- Modify the initialize_new_user function to ensure user record exists first
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
  -- Check if user exists in auth.users
  SELECT email, raw_user_meta_data->>'name' 
  INTO v_user_email, v_user_display_name
  FROM auth.users 
  WHERE id = p_user_id;
  
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
      COALESCE(v_user_display_name, split_part(v_user_email, '@', 1))
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

-- Modify the create_workspace_with_member function to ensure user exists
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
    -- Get user info from auth.users
    SELECT email, raw_user_meta_data->>'name' 
    INTO v_user_email, v_user_display_name
    FROM auth.users 
    WHERE id = p_owner_id;
    
    IF v_user_email IS NULL THEN
      RAISE EXCEPTION 'User not found in auth.users';
    END IF;
    
    INSERT INTO public.users (id, email, display_name)
    VALUES (
      p_owner_id, 
      v_user_email, 
      COALESCE(v_user_display_name, split_part(v_user_email, '@', 1))
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

-- Create a function to ensure user exists
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
    -- Get user info from auth.users
    SELECT email, raw_user_meta_data->>'name' 
    INTO v_user_email, v_user_display_name
    FROM auth.users 
    WHERE id = p_user_id;
    
    IF v_user_email IS NULL THEN
      RETURN FALSE;
    END IF;
    
    INSERT INTO public.users (id, email, display_name)
    VALUES (
      p_user_id, 
      v_user_email, 
      COALESCE(v_user_display_name, split_part(v_user_email, '@', 1))
    );
  END IF;
  
  RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;