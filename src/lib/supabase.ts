
import { createClient } from '@supabase/supabase-js';
import { Database } from '../types/supabase';

// For Vite, environment variables must be prefixed with VITE_
// These values are injected at build time from the environment
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || import.meta.env.SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.SUPABASE_ANON_KEY;
const supabaseServiceKey = import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY || import.meta.env.SUPABASE_SERVICE_ROLE_KEY;

// Validate environment variables
if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Supabase URL and Anon Key are required. Please check your environment variables.');
}

// Create Supabase client with the URL from Supabase project
export const supabase = createClient<Database>(
  supabaseUrl || 'https://oibcyeiuzuajixrdkqlj.supabase.co',
  supabaseAnonKey || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pYmN5ZWl1enVhaml4cmRrcWxqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMTA4ODYsImV4cCI6MjA2MDU4Njg4Nn0.jF3eoKs4BUt4Bn1TOZL4JoTdE6Fn9qWizBssFWY11BE',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
    }
  }
);

// Create a service role client for admin operations
// This should only be used for operations that require elevated privileges
export const supabaseAdmin = createClient<Database>(
  supabaseUrl || 'https://oibcyeiuzuajixrdkqlj.supabase.co',
  supabaseServiceKey || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pYmN5ZWl1enVhaml4cmRrcWxqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NTAxMDg4NiwiZXhwIjoyMDYwNTg2ODg2fQ.hyvaANDGe49dZzK2gOaKQbERMQFYTvaLSurKlNoipsc'
);

// Get user profile by ID
export const getUserProfile = async (userId: string) => {
  return supabaseAdmin.rpc('get_user_profile', {
    p_user_id: userId
  });
};

// Get auth user email by ID
export const getAuthUserEmail = async (userId: string) => {
  return supabaseAdmin.rpc('get_auth_user_email', {
    p_user_id: userId
  });
};

// Get auth user metadata by ID
export const getAuthUserMetadata = async (userId: string) => {
  return supabaseAdmin.rpc('get_auth_user_metadata', {
    p_user_id: userId
  });
};

// Ensure user exists in the public.users table
export const ensureUserExists = async (userId: string) => {
  return supabaseAdmin.rpc('ensure_user_exists', {
    p_user_id: userId
  });
};

// Create a function to call the initialize_new_user RPC
export const initializeNewUser = async (userId: string, workspaceName: string = 'My Workspace') => {
  return supabaseAdmin.rpc('initialize_new_user', {
    p_user_id: userId,
    p_workspace_name: workspaceName
  });
};

// Create a function to call the create_workspace_with_member RPC
export const createWorkspaceWithMember = async (name: string, ownerId: string) => {
  return supabaseAdmin.rpc('create_workspace_with_member', {
    p_name: name,
    p_owner_id: ownerId
  });
};

// Create a function to call the create_default_page RPC
export const createDefaultPage = async (
  workspaceId: string, 
  userId: string, 
  title: string = 'Welcome to your workspace'
) => {
  return supabaseAdmin.rpc('create_default_page', {
    p_workspace_id: workspaceId,
    p_user_id: userId,
    p_title: title
  });
};