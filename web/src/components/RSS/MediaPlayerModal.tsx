import { useEffect } from 'react';

interface MediaPlayerModalProps {
  isOpen: boolean;
  onClose: () => void;
  videoUrl: string | null;
}

export default function MediaPlayerModal({ isOpen, onClose, videoUrl }: MediaPlayerModalProps) {
  
  // Close on escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    if (isOpen) {
      window.addEventListener('keydown', handleKeyDown);
    }
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen || !videoUrl) return null;

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 animate-in fade-in duration-300">
      
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/90 backdrop-blur-md"
        onClick={onClose}
      />

      {/* Content */}
      <div className="relative w-full max-w-6xl aspect-video bg-black rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 border border-gray-800/50">
        
        {/* Close Button */}
        <button 
          onClick={onClose}
          className="absolute top-4 right-4 z-10 p-2 bg-black/50 hover:bg-black/80 text-white rounded-full transition-all hover:scale-110 backdrop-blur-sm group"
        >
          <svg className="w-6 h-6 group-hover:rotate-90 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        {/* Video Frame */}
        <div className="w-full h-full flex items-center justify-center">
            {videoUrl.includes('youtube') || videoUrl.includes('youtu.be') ? (
               <iframe 
                src={`${videoUrl.replace('watch?v=', 'embed/').replace('youtu.be/', 'www.youtube.com/embed/')}?autoplay=1`} 
                title="Video Player" 
                className="w-full h-full"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                allowFullScreen
              /> 
            ) : (
             <iframe 
                src={videoUrl} 
                title="Video Player" 
                className="w-full h-full"
                allowFullScreen
              />
            )}
        </div>
      </div>
    </div>
  );
}
