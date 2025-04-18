
import { useState } from 'react';
import { useWorkspace } from '../../context/WorkspaceContext';
import { PageWithChildren } from '../../types';
import { cn } from '../../lib/utils';
import { Button } from '../ui/button';
import { 
  ChevronRight, 
  File, 
  MoreHorizontal, 
  Plus, 
  Trash2,
  Star,
  GripVertical
} from 'lucide-react';
import { 
  DropdownMenu, 
  DropdownMenuContent, 
  DropdownMenuItem, 
  DropdownMenuTrigger 
} from '../ui/dropdown-menu';
import { useDndContext, DndContext, closestCenter } from '@dnd-kit/core';
import { toast } from 'react-hot-toast';

export function PageTree() {
  const { pages, currentPage, setCurrentPage, createPage, deletePage, updatePage, currentWorkspace } = useWorkspace();

  const handlePageClick = (page: PageWithChildren) => {
    setCurrentPage(page);
  };

  const handleCreateSubpage = async (parentId: string) => {
    if (!currentWorkspace) return;
    try {
      await createPage(currentWorkspace.id, parentId);
    } catch (error) {
      console.error('Error creating subpage:', error);
    }
  };

  const handleDeletePage = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await deletePage(id);
    } catch (error) {
      console.error('Error deleting page:', error);
    }
  };

  const handleToggleFavorite = async (page: PageWithChildren, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await updatePage(page.id, { is_favorite: !page.is_favorite });
    } catch (error) {
      console.error('Error toggling favorite:', error);
    }
  };

  const renderPageItem = (page: PageWithChildren, depth = 0) => {
    const [expanded, setExpanded] = useState(false);
    const hasChildren = page.children && page.children.length > 0;
    const isActive = currentPage?.id === page.id;

    return (
      <div key={page.id} className="select-none">
        <div
          className={cn(
            'group flex items-center rounded-md px-2 py-1.5 text-sm hover:bg-sidebar-accent hover:text-sidebar-accent-foreground',
            isActive && 'bg-sidebar-accent text-sidebar-accent-foreground'
          )}
          style={{ paddingLeft: `${(depth + 1) * 12}px` }}
        >
          <Button
            variant="ghost"
            size="icon"
            className={cn(
              'h-4 w-4 shrink-0 text-sidebar-foreground/50',
              hasChildren ? 'visible' : 'invisible'
            )}
            onClick={(e) => {
              e.stopPropagation();
              setExpanded(!expanded);
            }}
          >
            <ChevronRight
              size={14}
              className={cn('transition-transform', expanded && 'rotate-90')}
            />
          </Button>
          
          <div 
            className="flex-1 flex items-center gap-2 truncate cursor-pointer"
            onClick={() => handlePageClick(page)}
          >
            <GripVertical size={14} className="text-sidebar-foreground/30 opacity-0 group-hover:opacity-100" />
            <File size={14} className="shrink-0 text-sidebar-foreground/70" />
            <span className="truncate">{page.title || 'Untitled'}</span>
          </div>
          
          <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100">
            <Button
              variant="ghost"
              size="icon"
              className="h-6 w-6 text-sidebar-foreground/50 hover:text-sidebar-foreground"
              onClick={(e) => handleToggleFavorite(page, e)}
            >
              <Star size={14} className={cn(page.is_favorite && 'fill-yellow-400 text-yellow-400')} />
            </Button>
            
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-6 w-6 text-sidebar-foreground/50 hover:text-sidebar-foreground"
                  onClick={(e) => e.stopPropagation()}
                >
                  <MoreHorizontal size={14} />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-40">
                <DropdownMenuItem onClick={() => handleCreateSubpage(page.id)}>
                  <Plus size={14} className="mr-2" />
                  Add subpage
                </DropdownMenuItem>
                <DropdownMenuItem 
                  className="text-destructive focus:text-destructive"
                  onClick={(e) => handleDeletePage(page.id, e as React.MouseEvent)}
                >
                  <Trash2 size={14} className="mr-2" />
                  Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
        
        {expanded && hasChildren && (
          <div>
            {page.children!.map((childPage) => renderPageItem(childPage, depth + 1))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="space-y-1">
      {pages.map((page) => renderPageItem(page))}
      {pages.length === 0 && (
        <div className="px-2 py-4 text-center text-sm text-sidebar-foreground/50">
          No pages yet. Create your first page.
        </div>
      )}
    </div>
  );
}