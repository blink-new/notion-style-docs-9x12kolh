
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
import { ChevronDown, Plus, Loader2 } from 'lucide-react';
import { toast } from 'react-hot-toast';

export function WorkspaceSelector() {
  const { workspaces, currentWorkspace, setCurrentWorkspace, createWorkspace } = useWorkspace();
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [newWorkspaceName, setNewWorkspaceName] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleCreateWorkspace = async () => {
    if (!newWorkspaceName.trim()) {
      setError('Workspace name cannot be empty');
      return;
    }
    
    try {
      setError(null);
      setIsCreating(true);
      
      // Show a loading toast
      const loadingToast = toast.loading('Creating workspace...');
      
      const workspace = await createWorkspace(newWorkspaceName);
      
      // Dismiss the loading toast and show success
      toast.dismiss(loadingToast);
      toast.success('Workspace created successfully!');
      
      setCurrentWorkspace(workspace);
      setIsCreateDialogOpen(false);
      setNewWorkspaceName('');
    } catch (error: any) {
      console.error('Error creating workspace:', error);
      setError(error.message || 'Failed to create workspace. Please try again.');
      toast.error('Error creating workspace. Please try again.');
    } finally {
      setIsCreating(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !isCreating && newWorkspaceName.trim()) {
      handleCreateWorkspace();
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
                    onChange={(e) => {
                      setNewWorkspaceName(e.target.value);
                      setError(null); // Clear error when typing
                    }}
                    onKeyDown={handleKeyDown}
                    className={error ? "border-red-500" : ""}
                    autoFocus
                  />
                  {error && (
                    <p className="text-sm text-red-500">{error}</p>
                  )}
                </div>
              </div>
              <DialogFooter>
                <Button
                  variant="outline"
                  onClick={() => {
                    setIsCreateDialogOpen(false);
                    setError(null);
                    setNewWorkspaceName('');
                  }}
                  disabled={isCreating}
                >
                  Cancel
                </Button>
                <Button
                  onClick={handleCreateWorkspace}
                  disabled={!newWorkspaceName.trim() || isCreating}
                  className="min-w-[80px]"
                >
                  {isCreating ? (
                    <span className="flex items-center">
                      <Loader2 size={16} className="mr-2 animate-spin" />
                      Creating...
                    </span>
                  ) : (
                    'Create'
                  )}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}