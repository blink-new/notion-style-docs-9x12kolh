
import { useState, useEffect } from 'react';
import { useWorkspace } from '../../context/WorkspaceContext';
import { useAuth } from '../../context/AuthContext';
import { cn } from '../../lib/utils';
import { Button } from '../ui/button';
import { ScrollArea } from '../ui/scroll-area';
import { Separator } from '../ui/separator';
import { PageTree } from './PageTree';
import { WorkspaceSelector } from './WorkspaceSelector';
import { 
  ChevronLeft, 
  ChevronRight, 
  Plus, 
  Settings, 
  LogOut 
} from 'lucide-react';
import { useMobile } from '../../hooks/use-mobile';

interface SidebarProps {
  className?: string;
}

export function Sidebar({ className }: SidebarProps) {
  const { isMobile } = useMobile();
  const [collapsed, setCollapsed] = useState(isMobile);
  const { currentWorkspace, createPage } = useWorkspace();
  const { signOut } = useAuth();

  // Update collapsed state when screen size changes
  useEffect(() => {
    setCollapsed(isMobile);
  }, [isMobile]);

  const handleCreatePage = async () => {
    if (!currentWorkspace) return;
    try {
      await createPage(currentWorkspace.id);
    } catch (error) {
      console.error('Error creating page:', error);
    }
  };

  return (
    <div
      className={cn(
        'flex flex-col border-r bg-sidebar text-sidebar-foreground transition-all duration-300 ease-in-out',
        collapsed ? 'w-[50px]' : 'w-[260px]',
        className
      )}
    >
      <div className="flex items-center justify-between p-4 h-14">
        {!collapsed && (
          <WorkspaceSelector />
        )}
        <Button
          variant="ghost"
          size="icon"
          className="ml-auto text-sidebar-foreground"
          onClick={() => setCollapsed(!collapsed)}
        >
          {collapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
        </Button>
      </div>
      
      <Separator className="bg-sidebar-border" />
      
      <div className="flex-1 overflow-hidden">
        <ScrollArea className="h-full">
          <div className="p-2">
            {!collapsed && (
              <div className="space-y-1">
                <div className="flex items-center justify-between px-2 py-1.5">
                  <span className="text-xs font-medium text-sidebar-foreground/70">PAGES</span>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-5 w-5 text-sidebar-foreground/70 hover:text-sidebar-foreground"
                    onClick={handleCreatePage}
                  >
                    <Plus size={14} />
                  </Button>
                </div>
                
                <PageTree />
              </div>
            )}
          </div>
        </ScrollArea>
      </div>
      
      <Separator className="bg-sidebar-border" />
      
      <div className="p-2">
        {collapsed ? (
          <div className="flex flex-col items-center space-y-2">
            <Button
              variant="ghost"
              size="icon"
              className="text-sidebar-foreground/70 hover:text-sidebar-foreground"
              onClick={handleCreatePage}
            >
              <Plus size={18} />
            </Button>
            <Button
              variant="ghost"
              size="icon"
              className="text-sidebar-foreground/70 hover:text-sidebar-foreground"
            >
              <Settings size={18} />
            </Button>
            <Button
              variant="ghost"
              size="icon"
              className="text-sidebar-foreground/70 hover:text-sidebar-foreground"
              onClick={() => signOut()}
            >
              <LogOut size={18} />
            </Button>
          </div>
        ) : (
          <div className="flex flex-col space-y-1">
            <Button
              variant="ghost"
              className="w-full justify-start text-sidebar-foreground/70 hover:text-sidebar-foreground"
            >
              <Settings size={16} className="mr-2" />
              Settings
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start text-sidebar-foreground/70 hover:text-sidebar-foreground"
              onClick={() => signOut()}
            >
              <LogOut size={16} className="mr-2" />
              Sign out
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}