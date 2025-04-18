
import { useState } from 'react';
import { useWorkspace } from '../../context/WorkspaceContext';
import { Workspace } from '../../types';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '../ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu';
import { ChevronDown, Plus } from 'lucide-react';

export function WorkspaceSelector() {
  const { workspaces, currentWorkspace, setCurrentWorkspace, createWorkspace } = useWorkspace();
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [newWorkspaceName, setNewWorkspaceName] = useState('');
  const [isCreating, setIsCreating] = useState(false);

  const handleCreateWorkspace = async () => {
    if (!newWorkspaceName.trim()) return;
    
    try {
      setIsCreating(true);
      const workspace = await createWorkspace(newWorkspaceName);
      setCurrentWorkspace(workspace);
      setIsCreateDialogOpen(false);
      setNewWorkspaceName('');
    } catch (error) {
      console.error('Error creating workspace:', error);
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="flex items-center space-x-1">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="flex items-center justify-between w-[180px] px-2 text-left font-normal">
            <span className="truncate">{currentWorkspace?.name || 'Select workspace'}</span>
            <ChevronDown size={14} className="opacity-50" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-[220px]">
          {workspaces.map((workspace) => (
            <DropdownMenuItem
              key={workspace.id}
              onClick={() => setCurrentWorkspace(workspace)}
              className="cursor-pointer"
            >
              <span className="truncate">{workspace.name}</span>
            </DropdownMenuItem>
          ))}
          <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
            <DialogTrigger asChild>
              <Button variant="ghost" className="w-full justify-start px-2 py-1.5 text-sm font-normal">
                <Plus size={14} className="mr-2" />
                Create workspace
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create workspace</DialogTitle>
                <DialogDescription>
                  Create a new workspace to organize your documents.
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Input
                    placeholder="Workspace name"
                    value={newWorkspaceName}
                    onChange={(e) => setNewWorkspaceName(e.target.value)}
                  />
                </div>
              </div>
              <DialogFooter>
                <Button
                  variant="outline"
                  onClick={() => setIsCreateDialogOpen(false)}
                >
                  Cancel
                </Button>
                <Button
                  onClick={handleCreateWorkspace}
                  disabled={!newWorkspaceName.trim() || isCreating}
                >
                  {isCreating ? 'Creating...' : 'Create'}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}