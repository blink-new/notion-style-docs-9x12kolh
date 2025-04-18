
import { createClient } from '@supabase/supabase-js';
import { Database } from '../types/supabase';

// For Vite, environment variables must be prefixed with VITE_
// These values are injected at build time from the environment
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || import.meta.env.SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.SUPABASE_ANON_KEY;

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