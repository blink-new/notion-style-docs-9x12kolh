
import { useEffect } from 'react';
import { useWorkspace } from '../context/WorkspaceContext';
import { Sidebar } from '../components/layout/Sidebar';
import { Editor } from '../components/editor/Editor';
import { Loader2 } from 'lucide-react';

export function Dashboard() {
  const { loading } = useWorkspace();

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />
      <main className="flex-1 overflow-hidden">
        <Editor />
      </main>
    </div>
  );
}