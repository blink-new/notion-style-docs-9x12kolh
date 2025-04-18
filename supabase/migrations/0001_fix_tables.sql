
-- Fix tables for our Notion-style docs app

-- Check if tables exist and create them if they don't

-- Check and create users table
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
        -- Create users table to extend Supabase auth
        CREATE TABLE public.users (
          id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
          email TEXT UNIQUE NOT NULL,
          display_name TEXT,
          avatar_url TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
        );

        -- Enable RLS
        ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

        -- Create policies
        CREATE POLICY "Users can view their own profile"
          ON public.users FOR SELECT
          USING (auth.uid() = id);

        CREATE POLICY "Users can update their own profile"
          ON public.users FOR UPDATE
          USING (auth.uid() = id);
    END IF;
END
$$;

-- Check and create workspaces table
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'workspaces') THEN
        -- Create workspaces table
        CREATE TABLE public.workspaces (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          name TEXT NOT NULL,
          owner_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
        );

        -- Enable RLS
        ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;

        -- Create policies
        CREATE POLICY "Workspace owners can do everything"
          ON public.workspaces
          USING (owner_id = auth.uid());

        CREATE POLICY "Workspace members can view workspaces"
          ON public.workspaces FOR SELECT
          USING (
            EXISTS (
              SELECT 1 FROM public.workspace_members
              WHERE workspace_members.workspace_id = workspaces.id
              AND workspace_members.user_id = auth.uid()
            )
          );
    END IF;
END
$$;

-- Check and create pages table
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'pages') THEN
        -- Create pages table
        CREATE TABLE public.pages (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          title TEXT NOT NULL DEFAULT 'Untitled',
          content JSONB,
          workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
          parent_id UUID REFERENCES public.pages(id) ON DELETE CASCADE,
          icon TEXT,
          is_favorite BOOLEAN DEFAULT false,
          created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
          position INTEGER DEFAULT 0
        );

        -- Enable RLS
        ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;

        -- Create policies
        CREATE POLICY "Workspace owners can do everything with pages"
          ON public.pages
          USING (
            EXISTS (
              SELECT 1 FROM public.workspaces
              WHERE workspaces.id = pages.workspace_id
              AND workspaces.owner_id = auth.uid()
            )
          );

        CREATE POLICY "Workspace members can view pages"
          ON public.pages FOR SELECT
          USING (
            EXISTS (
              SELECT 1 FROM public.workspace_members
              WHERE workspace_members.workspace_id = pages.workspace_id
              AND workspace_members.user_id = auth.uid()
            )
          );
    END IF;
END
$$;

-- Check and create workspace_members table
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'workspace_members') THEN
        -- Create workspace_members table
        CREATE TABLE public.workspace_members (
          workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE,
          user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
          role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
          created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
          PRIMARY KEY (workspace_id, user_id)
        );

        -- Enable RLS
        ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;

        -- Create policies
        CREATE POLICY "Workspace owners can manage members"
          ON public.workspace_members
          USING (
            EXISTS (
              SELECT 1 FROM public.workspaces
              WHERE workspaces.id = workspace_members.workspace_id
              AND workspaces.owner_id = auth.uid()
            )
          );

        CREATE POLICY "Users can view workspace members"
          ON public.workspace_members FOR SELECT
          USING (
            EXISTS (
              SELECT 1 FROM public.workspace_members AS wm
              WHERE wm.workspace_id = workspace_members.workspace_id
              AND wm.user_id = auth.uid()
            )
          );
    END IF;
END
$$;

-- Check and create page_shares table
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'page_shares') THEN
        -- Create page_shares table
        CREATE TABLE public.page_shares (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          page_id UUID REFERENCES public.pages(id) ON DELETE CASCADE NOT NULL,
          access_level TEXT NOT NULL CHECK (access_level IN ('view', 'edit')),
          share_link TEXT UNIQUE NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
          expires_at TIMESTAMP WITH TIME ZONE
        );

        -- Enable RLS
        ALTER TABLE public.page_shares ENABLE ROW LEVEL SECURITY;

        -- Create policies
        CREATE POLICY "Workspace owners can manage page shares"
          ON public.page_shares
          USING (
            EXISTS (
              SELECT 1 FROM public.pages
              JOIN public.workspaces ON workspaces.id = pages.workspace_id
              WHERE pages.id = page_shares.page_id
              AND workspaces.owner_id = auth.uid()
            )
          );

        CREATE POLICY "Anyone can view page shares"
          ON public.page_shares FOR SELECT
          USING (true);
    END IF;
END
$$;

-- Create or replace functions and triggers

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Check and create triggers for updated_at
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_users_updated_at') THEN
        CREATE TRIGGER update_users_updated_at
        BEFORE UPDATE ON public.users
        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_workspaces_updated_at') THEN
        CREATE TRIGGER update_workspaces_updated_at
        BEFORE UPDATE ON public.workspaces
        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_pages_updated_at') THEN
        CREATE TRIGGER update_pages_updated_at
        BEFORE UPDATE ON public.pages
        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
    END IF;
END
$$;

-- Function to handle user creation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name)
  VALUES (NEW.id, NEW.email, split_part(NEW.email, '@', 1));
  
  -- Create a default workspace for new users
  INSERT INTO public.workspaces (name, owner_id)
  VALUES ('My Workspace', NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Check and create trigger for new user creation
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN
        CREATE TRIGGER on_auth_user_created
        AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE FUNCTION handle_new_user();
    END IF;
END
$$;

-- Function to add workspace owner as a member
CREATE OR REPLACE FUNCTION add_workspace_owner_as_member()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner');
  
  -- Create a default welcome page
  INSERT INTO public.pages (title, content, workspace_id, created_by)
  VALUES (
    'Welcome to your workspace',
    '{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Welcome to your new workspace!"}]},{"type":"paragraph","content":[{"type":"text","text":"This is your first page. You can edit it or create new pages using the sidebar."}]}]}',
    NEW.id,
    NEW.owner_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Check and create trigger for adding workspace owner as member
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_workspace_created') THEN
        CREATE TRIGGER on_workspace_created
        AFTER INSERT ON public.workspaces
        FOR EACH ROW EXECUTE FUNCTION add_workspace_owner_as_member();
    END IF;
END
$$;