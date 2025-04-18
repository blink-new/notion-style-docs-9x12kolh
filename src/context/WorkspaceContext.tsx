
import { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from './AuthContext';
import { Page, PageWithChildren, Workspace, WorkspaceWithPages } from '../types';
import { toast } from 'react-hot-toast';

type WorkspaceContextType = {
  workspaces: Workspace[];
  currentWorkspace: WorkspaceWithPages | null;
  pages: PageWithChildren[];
  currentPage: Page | null;
  loading: boolean;
  setCurrentWorkspace: (workspace: Workspace | null) => void;
  setCurrentPage: (page: Page | null) => void;
  createWorkspace: (name: string) => Promise<Workspace>;
  updateWorkspace: (id: string, name: string) => Promise<void>;
  deleteWorkspace: (id: string) => Promise<void>;
  createPage: (workspaceId: string, parentId?: string | null) => Promise<Page>;
  updatePage: (id: string, data: Partial<Page>) => Promise<void>;
  deletePage: (id: string) => Promise<void>;
  reorderPages: (pageId: string, newPosition: number) => Promise<void>;
  refreshPages: () => Promise<void>;
  refreshWorkspaces: () => Promise<void>;
};

const WorkspaceContext = createContext<WorkspaceContextType | undefined>(undefined);

export function WorkspaceProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const [workspaces, setWorkspaces] = useState<Workspace[]>([]);
  const [currentWorkspace, setCurrentWorkspace] = useState<WorkspaceWithPages | null>(null);
  const [pages, setPages] = useState<PageWithChildren[]>([]);
  const [currentPage, setCurrentPage] = useState<Page | null>(null);
  const [loading, setLoading] = useState(true);
  const [fetchAttempts, setFetchAttempts] = useState(0);

  // Fetch workspaces when user changes
  useEffect(() => {
    if (user) {
      fetchWorkspaces();
    } else {
      setWorkspaces([]);
      setCurrentWorkspace(null);
      setPages([]);
      setCurrentPage(null);
      setLoading(false);
    }
  }, [user]);

  // Fetch pages when current workspace changes
  useEffect(() => {
    if (currentWorkspace) {
      fetchPages(currentWorkspace.id);
    }
  }, [currentWorkspace]);

  const fetchWorkspaces = async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      
      // First ensure the user exists in the users table
      try {
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', user.id)
          .single();
        
        if (userError) {
          console.log('User not found, creating user record');
          
          // Create the user if they don't exist
          const { error: insertError } = await supabase
            .from('users')
            .insert({
              id: user.id,
              email: user.email || '',
              display_name: user.email ? user.email.split('@')[0] : 'User'
            });
            
          if (insertError) {
            console.error('Error creating user:', insertError);
          }
        }
      } catch (userCheckError) {
        console.error('Error checking user:', userCheckError);
      }
      
      // Now fetch workspaces with a more direct query
      const { data, error } = await supabase
        .from('workspaces')
        .select('*')
        .eq('owner_id', user.id)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('Error fetching workspaces:', error);
        
        // If we've tried less than 3 times and got an error, try to create a default workspace
        if (fetchAttempts < 3) {
          setFetchAttempts(prev => prev + 1);
          await createDefaultWorkspace();
          return;
        }
        
        throw error;
      }
      
      // Reset fetch attempts on successful fetch
      setFetchAttempts(0);
      
      // If no workspaces found, create a default one
      if (!data || data.length === 0) {
        await createDefaultWorkspace();
        return;
      }
      
      setWorkspaces(data);
      
      // Set first workspace as current if none is selected
      if (data.length > 0 && !currentWorkspace) {
        const firstWorkspace = data[0];
        const workspaceWithPages = { ...firstWorkspace, pages: [] };
        setCurrentWorkspace(workspaceWithPages);
      }
    } catch (error: any) {
      console.error('Workspace fetch error:', error);
      toast.error('Error loading workspaces. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const createDefaultWorkspace = async () => {
    if (!user) return;
    
    try {
      console.log('Creating default workspace for user:', user.id);
      
      // First check if the user already has any workspaces
      const { data: existingWorkspaces, error: checkError } = await supabase
        .from('workspaces')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1);
        
      if (checkError) {
        console.error('Error checking existing workspaces:', checkError);
      }
      
      // Only create a new workspace if the user doesn't have any
      if (!existingWorkspaces || existingWorkspaces.length === 0) {
        const { data, error } = await supabase
          .from('workspaces')
          .insert({ 
            name: 'My Workspace', 
            owner_id: user.id 
          })
          .select()
          .single();

        if (error) {
          console.error('Error creating default workspace:', error);
          throw error;
        }
        
        // Also create the workspace_member record manually
        const { error: memberError } = await supabase
          .from('workspace_members')
          .insert({
            workspace_id: data.id,
            user_id: user.id,
            role: 'owner'
          });
          
        if (memberError) {
          console.error('Error creating workspace member:', memberError);
        }
        
        // Create a welcome page
        const { error: pageError } = await supabase
          .from('pages')
          .insert({
            title: 'Welcome to your workspace',
            content: {
              type: 'doc',
              content: [
                {
                  type: 'heading',
                  attrs: { level: 1 },
                  content: [{ type: 'text', text: 'Welcome to your new workspace!' }]
                },
                {
                  type: 'paragraph',
                  content: [{ type: 'text', text: 'This is your first page. You can edit it or create new pages using the sidebar.' }]
                }
              ]
            },
            workspace_id: data.id,
            created_by: user.id
          });
          
        if (pageError) {
          console.error('Error creating welcome page:', pageError);
        }
        
        setWorkspaces([data]);
        setCurrentWorkspace({ ...data, pages: [] });
        
        // Fetch workspaces again to ensure everything is up to date
        setTimeout(() => {
          fetchWorkspaces();
        }, 500);
      } else {
        // If workspaces exist but weren't fetched properly, try again
        setTimeout(() => {
          fetchWorkspaces();
        }, 500);
      }
    } catch (error: any) {
      console.error('Default workspace creation error:', error);
      toast.error('Error creating workspace. Please try again.');
    }
  };

  const fetchPages = async (workspaceId: string) => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('pages')
        .select('*')
        .eq('workspace_id', workspaceId)
        .order('position', { ascending: true });

      if (error) {
        console.error('Error fetching pages:', error);
        throw error;
      }
      
      // Organize pages into a tree structure
      const pagesWithChildren = organizePages(data || []);
      setPages(pagesWithChildren);
      
      // Update current workspace with pages
      if (currentWorkspace) {
        setCurrentWorkspace({
          ...currentWorkspace,
          pages: pagesWithChildren
        });
      }
      
      // Set first page as current if none is selected
      if (data && data.length > 0 && !currentPage) {
        setCurrentPage(data[0]);
      }
    } catch (error: any) {
      console.error('Page fetch error:', error);
      toast.error('Error loading pages. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const organizePages = (pages: Page[]): PageWithChildren[] => {
    const pageMap = new Map<string, PageWithChildren>();
    const rootPages: PageWithChildren[] = [];

    // First pass: create all page objects with empty children arrays
    pages.forEach(page => {
      pageMap.set(page.id, { ...page, children: [] });
    });

    // Second pass: organize into parent-child relationships
    pages.forEach(page => {
      const pageWithChildren = pageMap.get(page.id)!;
      
      if (page.parent_id && pageMap.has(page.parent_id)) {
        // Add as child to parent
        const parent = pageMap.get(page.parent_id)!;
        parent.children!.push(pageWithChildren);
      } else {
        // Add to root pages
        rootPages.push(pageWithChildren);
      }
    });

    return rootPages;
  };

  const createWorkspace = async (name: string): Promise<Workspace> => {
    try {
      if (!user) throw new Error('User not authenticated');
      
      const { data, error } = await supabase
        .from('workspaces')
        .insert({ name, owner_id: user.id })
        .select()
        .single();

      if (error) {
        console.error('Error creating workspace:', error);
        throw error;
      }
      
      // Manually create the workspace_member record
      const { error: memberError } = await supabase
        .from('workspace_members')
        .insert({
          workspace_id: data.id,
          user_id: user.id,
          role: 'owner'
        });
        
      if (memberError) {
        console.error('Error creating workspace member:', memberError);
      }
      
      await refreshWorkspaces();
      return data;
    } catch (error: any) {
      console.error('Workspace creation error:', error);
      toast.error('Error creating workspace. Please try again.');
      throw error;
    }
  };

  const updateWorkspace = async (id: string, name: string): Promise<void> => {
    try {
      const { error } = await supabase
        .from('workspaces')
        .update({ name })
        .eq('id', id);

      if (error) {
        console.error('Error updating workspace:', error);
        throw error;
      }
      
      setWorkspaces(prev => 
        prev.map(workspace => 
          workspace.id === id ? { ...workspace, name } : workspace
        )
      );
      
      if (currentWorkspace?.id === id) {
        setCurrentWorkspace(prev => prev ? { ...prev, name } : null);
      }
      
      toast.success('Workspace updated');
    } catch (error: any) {
      console.error('Workspace update error:', error);
      toast.error('Error updating workspace. Please try again.');
      throw error;
    }
  };

  const deleteWorkspace = async (id: string): Promise<void> => {
    try {
      const { error } = await supabase
        .from('workspaces')
        .delete()
        .eq('id', id);

      if (error) {
        console.error('Error deleting workspace:', error);
        throw error;
      }
      
      setWorkspaces(prev => prev.filter(workspace => workspace.id !== id));
      
      if (currentWorkspace?.id === id) {
        const nextWorkspace = workspaces.find(w => w.id !== id);
        if (nextWorkspace) {
          setCurrentWorkspace({ ...nextWorkspace, pages: [] });
        } else {
          setCurrentWorkspace(null);
        }
      }
      
      toast.success('Workspace deleted');
    } catch (error: any) {
      console.error('Workspace deletion error:', error);
      toast.error('Error deleting workspace. Please try again.');
      throw error;
    }
  };

  const createPage = async (workspaceId: string, parentId?: string | null): Promise<Page> => {
    try {
      if (!user) throw new Error('User not authenticated');
      
      // Get the highest position to place the new page at the end
      const { data: existingPages, error: positionError } = await supabase
        .from('pages')
        .select('position')
        .eq('workspace_id', workspaceId)
        .eq('parent_id', parentId || null)
        .order('position', { ascending: false })
        .limit(1);
      
      if (positionError) {
        console.error('Error getting page positions:', positionError);
      }
      
      const position = existingPages && existingPages.length > 0 
        ? existingPages[0].position + 1 
        : 0;
      
      const { data, error } = await supabase
        .from('pages')
        .insert({
          title: 'Untitled',
          workspace_id: workspaceId,
          parent_id: parentId || null,
          created_by: user.id,
          position,
          content: {
            type: 'doc',
            content: [
              {
                type: 'paragraph',
                content: [{ type: 'text', text: '' }]
              }
            ]
          }
        })
        .select()
        .single();

      if (error) {
        console.error('Error creating page:', error);
        throw error;
      }
      
      await refreshPages();
      return data;
    } catch (error: any) {
      console.error('Page creation error:', error);
      toast.error('Error creating page. Please try again.');
      throw error;
    }
  };

  const updatePage = async (id: string, data: Partial<Page>): Promise<void> => {
    try {
      const { error } = await supabase
        .from('pages')
        .update(data)
        .eq('id', id);

      if (error) {
        console.error('Error updating page:', error);
        throw error;
      }
      
      // Update pages state
      setPages(prev => updatePageInTree(prev, id, data));
      
      // Update current page if it's the one being updated
      if (currentPage?.id === id) {
        setCurrentPage(prev => prev ? { ...prev, ...data } : null);
      }
    } catch (error: any) {
      console.error('Page update error:', error);
      toast.error('Error updating page. Please try again.');
      throw error;
    }
  };

  const updatePageInTree = (
    pages: PageWithChildren[],
    id: string,
    data: Partial<Page>
  ): PageWithChildren[] => {
    return pages.map(page => {
      if (page.id === id) {
        return { ...page, ...data, children: page.children };
      }
      if (page.children && page.children.length > 0) {
        return {
          ...page,
          children: updatePageInTree(page.children, id, data)
        };
      }
      return page;
    });
  };

  const deletePage = async (id: string): Promise<void> => {
    try {
      const { error } = await supabase
        .from('pages')
        .delete()
        .eq('id', id);

      if (error) {
        console.error('Error deleting page:', error);
        throw error;
      }
      
      // If current page is deleted, set to null
      if (currentPage?.id === id) {
        setCurrentPage(null);
      }
      
      await refreshPages();
      toast.success('Page deleted');
    } catch (error: any) {
      console.error('Page deletion error:', error);
      toast.error('Error deleting page. Please try again.');
      throw error;
    }
  };

  const reorderPages = async (pageId: string, newPosition: number): Promise<void> => {
    try {
      // Find the page to be reordered
      let targetPage: Page | null = null;
      const findPage = (pages: PageWithChildren[]): boolean => {
        for (const page of pages) {
          if (page.id === pageId) {
            targetPage = page;
            return true;
          }
          if (page.children && page.children.length > 0) {
            if (findPage(page.children)) {
              return true;
            }
          }
        }
        return false;
      };
      
      findPage(pages);
      
      if (!targetPage) {
        throw new Error('Page not found');
      }
      
      // Get all siblings
      const { data: siblings, error } = await supabase
        .from('pages')
        .select('*')
        .eq('workspace_id', targetPage.workspace_id)
        .eq('parent_id', targetPage.parent_id)
        .order('position', { ascending: true });
        
      if (error) {
        console.error('Error fetching sibling pages:', error);
        throw error;
      }
      
      // Calculate new positions
      const updatedPositions = siblings
        .filter(p => p.id !== pageId) // Remove the page being moved
        .map((page, index) => {
          let position = index;
          if (index >= newPosition) position += 1; // Make space for the moved page
          return { id: page.id, position };
        });
      
      // Add the moved page with its new position
      updatedPositions.push({ id: pageId, position: newPosition });
      
      // Update all positions in a transaction
      for (const { id, position } of updatedPositions) {
        const { error: updateError } = await supabase
          .from('pages')
          .update({ position })
          .eq('id', id);
          
        if (updateError) {
          console.error(`Error updating position for page ${id}:`, updateError);
          throw updateError;
        }
      }
      
      await refreshPages();
    } catch (error: any) {
      console.error('Page reordering error:', error);
      toast.error('Error reordering pages. Please try again.');
      throw error;
    }
  };

  const refreshPages = async () => {
    if (currentWorkspace) {
      await fetchPages(currentWorkspace.id);
    }
  };

  const refreshWorkspaces = async () => {
    await fetchWorkspaces();
  };

  const value = {
    workspaces,
    currentWorkspace,
    pages,
    currentPage,
    loading,
    setCurrentWorkspace,
    setCurrentPage,
    createWorkspace,
    updateWorkspace,
    deleteWorkspace,
    createPage,
    updatePage,
    deletePage,
    reorderPages,
    refreshPages,
    refreshWorkspaces,
  };

  return <WorkspaceContext.Provider value={value}>{children}</WorkspaceContext.Provider>;
}

export const useWorkspace = () => {
  const context = useContext(WorkspaceContext);
  if (context === undefined) {
    throw new Error('useWorkspace must be used within a WorkspaceProvider');
  }
  return context;
};