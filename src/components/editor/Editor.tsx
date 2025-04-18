
import { useEffect, useState } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Placeholder from '@tiptap/extension-placeholder';
import Link from '@tiptap/extension-link';
import Image from '@tiptap/extension-image';
import TextAlign from '@tiptap/extension-text-align';
import TaskList from '@tiptap/extension-task-list';
import TaskItem from '@tiptap/extension-task-item';
import Highlight from '@tiptap/extension-highlight';
import Underline from '@tiptap/extension-underline';
import { useWorkspace } from '../../context/WorkspaceContext';
import { EditorToolbar } from './EditorToolbar';
import { debounce } from '../../lib/utils';
import './editor.css';

export function Editor() {
  const { currentPage, updatePage } = useWorkspace();
  const [title, setTitle] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  const editor = useEditor({
    extensions: [
      // StarterKit already includes: heading, bulletList, orderedList, codeBlock, blockquote, strike, code
      // So we don't need to import them separately
      StarterKit.configure({
        heading: {
          levels: [1, 2, 3],
        },
      }),
      Placeholder.configure({
        placeholder: 'Start writing...',
      }),
      Link.configure({
        openOnClick: true,
        HTMLAttributes: {
          class: 'text-primary underline underline-offset-2',
        },
      }),
      Image,
      TextAlign.configure({
        types: ['heading', 'paragraph'],
      }),
      TaskList,
      TaskItem.configure({
        nested: true,
      }),
      Highlight,
      Underline,
    ],
    content: '',
    autofocus: 'end',
    editorProps: {
      attributes: {
        class: 'prose prose-sm sm:prose lg:prose-lg mx-auto focus:outline-none',
      },
    },
  });

  // Update editor content when current page changes
  useEffect(() => {
    if (editor && currentPage) {
      setTitle(currentPage.title);
      
      if (currentPage.content) {
        editor.commands.setContent(currentPage.content);
      } else {
        editor.commands.clearContent();
      }
    }
  }, [editor, currentPage]);

  // Save changes when editor content changes
  useEffect(() => {
    if (!editor || !currentPage) return;

    const saveChanges = debounce(async () => {
      try {
        setIsSaving(true);
        await updatePage(currentPage.id, {
          content: editor.getJSON(),
        });
      } catch (error) {
        console.error('Error saving content:', error);
      } finally {
        setIsSaving(false);
      }
    }, 1000);

    const handleUpdate = () => {
      saveChanges();
    };

    editor.on('update', handleUpdate);

    return () => {
      editor.off('update', handleUpdate);
    };
  }, [editor, currentPage, updatePage]);

  // Handle title change
  const handleTitleChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const newTitle = e.target.value;
    setTitle(newTitle);
    
    if (currentPage) {
      try {
        await updatePage(currentPage.id, { title: newTitle });
      } catch (error) {
        console.error('Error updating title:', error);
      }
    }
  };

  if (!currentPage) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
        <p>Select a page or create a new one</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="flex items-center justify-between p-4 border-b">
        <input
          type="text"
          value={title}
          onChange={handleTitleChange}
          placeholder="Untitled"
          className="text-xl font-bold bg-transparent border-none outline-none w-full"
        />
        <div className="text-xs text-muted-foreground">
          {isSaving ? 'Saving...' : 'Saved'}
        </div>
      </div>
      
      {editor && <EditorToolbar editor={editor} />}
      
      <div className="flex-1 overflow-y-auto p-4">
        <div className="max-w-3xl mx-auto">
          <EditorContent editor={editor} className="min-h-[calc(100vh-200px)]" />
        </div>
      </div>
    </div>
  );
}