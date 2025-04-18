
-- Create tables for our Notion-style docs app

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table to extend Supabase auth
CREATE TABLE IF NOT EXISTS users (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Create workspaces table
CREATE TABLE IF NOT EXISTS workspaces (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  owner_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Create pages table
CREATE TABLE IF NOT EXISTS pages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL DEFAULT 'Untitled',
  content JSONB,
  workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE NOT NULL,
  parent_id UUID REFERENCES pages(id) ON DELETE CASCADE,
  icon TEXT,
  is_favorite BOOLEAN DEFAULT false,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  position INTEGER DEFAULT 0
);

-- Create workspace_members table for collaboration
CREATE TABLE IF NOT EXISTS workspace_members (
  workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (workspace_id, user_id)
);

-- Create page_shares table for sharing pages
CREATE TABLE IF NOT EXISTS page_shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  page_id UUID REFERENCES pages(id) ON DELETE CASCADE NOT NULL,
  access_level TEXT NOT NULL CHECK (access_level IN ('view', 'edit')),
  share_link TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE
);

-- Create RLS policies

-- Users table policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Workspaces table policies
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Workspace owners can do everything"
  ON workspaces
  USING (owner_id = auth.uid());

CREATE POLICY "Workspace members can view workspaces"
  ON workspaces FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM workspace_members
      WHERE workspace_members.workspace_id = workspaces.id
      AND workspace_members.user_id = auth.uid()
    )
  );

-- Pages table policies
ALTER TABLE pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Workspace owners can do everything with pages"
  ON pages
  USING (
    EXISTS (
      SELECT 1 FROM workspaces
      WHERE workspaces.id = pages.workspace_id
      AND workspaces.owner_id = auth.uid()
    )
  );

CREATE POLICY "Workspace editors can edit pages"
  ON pages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM workspace_members
      WHERE workspace_members.workspace_id = pages.workspace_id
      AND workspace_members.user_id = auth.uid()
      AND workspace_members.role IN ('owner', 'editor')
    )
  );

CREATE POLICY "Workspace members can view pages"
  ON pages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM workspace_members
      WHERE workspace_members.workspace_id = pages.workspace_id
      AND workspace_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Anyone with share link can view shared pages"
  ON pages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM page_shares
      WHERE page_shares.page_id = pages.id
    )
  );

-- Workspace members table policies
ALTER TABLE workspace_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Workspace owners can manage members"
  ON workspace_members
  USING (
    EXISTS (
      SELECT 1 FROM workspaces
      WHERE workspaces.id = workspace_members.workspace_id
      AND workspaces.owner_id = auth.uid()
    )
  );

CREATE POLICY "Users can view workspace members"
  ON workspace_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM workspace_members AS wm
      WHERE wm.workspace_id = workspace_members.workspace_id
      AND wm.user_id = auth.uid()
    )
  );

-- Page shares table policies
ALTER TABLE page_shares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Workspace owners can manage page shares"
  ON page_shares
  USING (
    EXISTS (
      SELECT 1 FROM pages
      JOIN workspaces ON workspaces.id = pages.workspace_id
      WHERE pages.id = page_shares.page_id
      AND workspaces.owner_id = auth.uid()
    )
  );

CREATE POLICY "Anyone can view page shares"
  ON page_shares FOR SELECT
  USING (true);

-- Create functions and triggers

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_workspaces_updated_at
BEFORE UPDATE ON workspaces
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_pages_updated_at
BEFORE UPDATE ON pages
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to handle user creation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO users (id, email, display_name)
  VALUES (NEW.id, NEW.email, split_part(NEW.email, '@', 1));
  
  -- Create a default workspace for new users
  INSERT INTO workspaces (name, owner_id)
  VALUES ('My Workspace', NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for new user creation
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to add workspace owner as a member
CREATE OR REPLACE FUNCTION add_workspace_owner_as_member()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO workspace_members (workspace_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner');
  
  -- Create a default welcome page
  INSERT INTO pages (title, content, workspace_id, created_by)
  VALUES (
    'Welcome to your workspace',
    '{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Welcome to your new workspace!"}]},{"type":"paragraph","content":[{"type":"text","text":"This is your first page. You can edit it or create new pages using the sidebar."}]}]}',
    NEW.id,
    NEW.owner_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for adding workspace owner as member
CREATE TRIGGER on_workspace_created
AFTER INSERT ON workspaces
FOR EACH ROW EXECUTE FUNCTION add_workspace_owner_as_member();