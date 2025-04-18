
import { Database } from './supabase';

export type User = Database['public']['Tables']['users']['Row'];
export type Workspace = Database['public']['Tables']['workspaces']['Row'];
export type Page = Database['public']['Tables']['pages']['Row'];
export type WorkspaceMember = Database['public']['Tables']['workspace_members']['Row'];
export type PageShare = Database['public']['Tables']['page_shares']['Row'];

export type PageWithChildren = Page & {
  children?: PageWithChildren[];
};

export type WorkspaceWithPages = Workspace & {
  pages: PageWithChildren[];
};