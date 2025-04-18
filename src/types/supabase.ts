
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string
          email: string
          display_name: string | null
          avatar_url: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          email: string
          display_name?: string | null
          avatar_url?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string
          display_name?: string | null
          avatar_url?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      workspaces: {
        Row: {
          id: string
          name: string
          owner_id: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          name: string
          owner_id: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          name?: string
          owner_id?: string
          created_at?: string
          updated_at?: string
        }
      }
      pages: {
        Row: {
          id: string
          title: string
          content: Json | null
          workspace_id: string
          parent_id: string | null
          icon: string | null
          is_favorite: boolean
          created_by: string | null
          created_at: string
          updated_at: string
          position: number
        }
        Insert: {
          id?: string
          title?: string
          content?: Json | null
          workspace_id: string
          parent_id?: string | null
          icon?: string | null
          is_favorite?: boolean
          created_by?: string | null
          created_at?: string
          updated_at?: string
          position?: number
        }
        Update: {
          id?: string
          title?: string
          content?: Json | null
          workspace_id?: string
          parent_id?: string | null
          icon?: string | null
          is_favorite?: boolean
          created_by?: string | null
          created_at?: string
          updated_at?: string
          position?: number
        }
      }
      workspace_members: {
        Row: {
          workspace_id: string
          user_id: string
          role: string
          created_at: string
        }
        Insert: {
          workspace_id: string
          user_id: string
          role: string
          created_at?: string
        }
        Update: {
          workspace_id?: string
          user_id?: string
          role?: string
          created_at?: string
        }
      }
      page_shares: {
        Row: {
          id: string
          page_id: string
          access_level: string
          share_link: string
          created_at: string
          expires_at: string | null
        }
        Insert: {
          id?: string
          page_id: string
          access_level: string
          share_link: string
          created_at?: string
          expires_at?: string | null
        }
        Update: {
          id?: string
          page_id?: string
          access_level?: string
          share_link?: string
          created_at?: string
          expires_at?: string | null
        }
      }
    }
  }
}