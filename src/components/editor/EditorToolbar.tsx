
import { Editor } from '@tiptap/react';
import { 
  Bold, 
  Italic, 
  Underline, 
  Strikethrough, 
  Code, 
  Heading1, 
  Heading2, 
  Heading3, 
  List, 
  ListOrdered, 
  CheckSquare, 
  Quote, 
  Link, 
  Image, 
  AlignLeft, 
  AlignCenter, 
  AlignRight, 
  Highlighter,
  Undo,
  Redo
} from 'lucide-react';
import { Button } from '../ui/button';
import { Separator } from '../ui/separator';
import { cn } from '../../lib/utils';
import { 
  Tooltip, 
  TooltipContent, 
  TooltipProvider, 
  TooltipTrigger 
} from '../ui/tooltip';

interface EditorToolbarProps {
  editor: Editor;
}

export function EditorToolbar({ editor }: EditorToolbarProps) {
  if (!editor) {
    return null;
  }

  const addImage = () => {
    const url = window.prompt('URL');
    if (url) {
      editor.chain().focus().setImage({ src: url }).run();
    }
  };

  const setLink = () => {
    const previousUrl = editor.getAttributes('link').href;
    const url = window.prompt('URL', previousUrl);
    
    if (url === null) {
      return;
    }

    if (url === '') {
      editor.chain().focus().extendMarkRange('link').unsetLink().run();
      return;
    }

    editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run();
  };

  return (
    <TooltipProvider>
      <div className="border-b p-1 flex flex-wrap items-center gap-1 sticky top-0 bg-background z-10">
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleBold().run()}
          active={editor.isActive('bold')}
          tooltip="Bold"
        >
          <Bold size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleItalic().run()}
          active={editor.isActive('italic')}
          tooltip="Italic"
        >
          <Italic size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleUnderline().run()}
          active={editor.isActive('underline')}
          tooltip="Underline"
        >
          <Underline size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleStrike().run()}
          active={editor.isActive('strike')}
          tooltip="Strikethrough"
        >
          <Strikethrough size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleHighlight().run()}
          active={editor.isActive('highlight')}
          tooltip="Highlight"
        >
          <Highlighter size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleCode().run()}
          active={editor.isActive('code')}
          tooltip="Inline Code"
        >
          <Code size={16} />
        </ToolbarButton>
        
        <Separator orientation="vertical" className="h-6" />
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
          active={editor.isActive('heading', { level: 1 })}
          tooltip="Heading 1"
        >
          <Heading1 size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
          active={editor.isActive('heading', { level: 2 })}
          tooltip="Heading 2"
        >
          <Heading2 size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}
          active={editor.isActive('heading', { level: 3 })}
          tooltip="Heading 3"
        >
          <Heading3 size={16} />
        </ToolbarButton>
        
        <Separator orientation="vertical" className="h-6" />
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleBulletList().run()}
          active={editor.isActive('bulletList')}
          tooltip="Bullet List"
        >
          <List size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleOrderedList().run()}
          active={editor.isActive('orderedList')}
          tooltip="Ordered List"
        >
          <ListOrdered size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleTaskList().run()}
          active={editor.isActive('taskList')}
          tooltip="Task List"
        >
          <CheckSquare size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleBlockquote().run()}
          active={editor.isActive('blockquote')}
          tooltip="Quote"
        >
          <Quote size={16} />
        </ToolbarButton>
        
        <Separator orientation="vertical" className="h-6" />
        
        <ToolbarButton
          onClick={() => editor.chain().focus().setTextAlign('left').run()}
          active={editor.isActive({ textAlign: 'left' })}
          tooltip="Align Left"
        >
          <AlignLeft size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().setTextAlign('center').run()}
          active={editor.isActive({ textAlign: 'center' })}
          tooltip="Align Center"
        >
          <AlignCenter size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().setTextAlign('right').run()}
          active={editor.isActive({ textAlign: 'right' })}
          tooltip="Align Right"
        >
          <AlignRight size={16} />
        </ToolbarButton>
        
        <Separator orientation="vertical" className="h-6" />
        
        <ToolbarButton
          onClick={setLink}
          active={editor.isActive('link')}
          tooltip="Link"
        >
          <Link size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={addImage}
          active={editor.isActive('image')}
          tooltip="Image"
        >
          <Image size={16} />
        </ToolbarButton>
        
        <Separator orientation="vertical" className="h-6" />
        
        <ToolbarButton
          onClick={() => editor.chain().focus().undo().run()}
          disabled={!editor.can().undo()}
          tooltip="Undo"
        >
          <Undo size={16} />
        </ToolbarButton>
        
        <ToolbarButton
          onClick={() => editor.chain().focus().redo().run()}
          disabled={!editor.can().redo()}
          tooltip="Redo"
        >
          <Redo size={16} />
        </ToolbarButton>
      </div>
    </TooltipProvider>
  );
}

interface ToolbarButtonProps {
  onClick: () => void;
  active?: boolean;
  disabled?: boolean;
  tooltip: string;
  children: React.ReactNode;
}

function ToolbarButton({ onClick, active, disabled, tooltip, children }: ToolbarButtonProps) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className={cn(
            'h-8 w-8',
            active && 'bg-accent text-accent-foreground'
          )}
          onClick={onClick}
          disabled={disabled}
        >
          {children}
        </Button>
      </TooltipTrigger>
      <TooltipContent>{tooltip}</TooltipContent>
    </Tooltip>
  );
}