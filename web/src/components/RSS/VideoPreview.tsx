import { useState, useEffect } from 'react';

interface VideoPreviewProps {
  videoUrl: string;
  onPlay: () => void;
  title?: string;
}

export default function VideoPreview({ videoUrl, onPlay, title = 'Riproduci Video' }: VideoPreviewProps) {
  const [thumbnailUrl, setThumbnailUrl] = useState<string | null>(null);

  useEffect(() => {
    // Attempt to extract YouTube thumbnail
    const getYouTubeId = (url: string) => {
      const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=)([^#&?]*).*/;
      const match = url.match(regExp);
      return (match && match[2].length === 11) ? match[2] : null;
    };

    const ytId = getYouTubeId(videoUrl);
    if (ytId) {
      setThumbnailUrl(`https://img.youtube.com/vi/${ytId}/hqdefault.jpg`);
    }
  }, [videoUrl]);

  return (
    <div 
      className="relative w-full aspect-video rounded-2xl overflow-hidden my-8 group cursor-pointer shadow-lg hover:shadow-xl transition-all border border-gray-200 dark:border-gray-700 bg-gray-100 dark:bg-gray-800"
      onClick={onPlay}
    >
      {/* Background / Thumbnail */}
      {thumbnailUrl ? (
        <img 
          src={thumbnailUrl} 
          alt="Video Thumbnail" 
          className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105 opacity-90 group-hover:opacity-100"
        />
      ) : (
        <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-purple-500/10 to-pink-500/10 dark:from-indigo-900/40 dark:via-purple-900/40 dark:to-pink-900/40 flex items-center justify-center">
            <svg className="w-20 h-20 text-indigo-300/50" fill="currentColor" viewBox="0 0 24 24">
                <path d="M19.615 3.184c-3.604-.246-11.631-.245-15.23 0-3.897.266-4.356 2.62-4.385 8.816.029 6.185.484 8.549 4.385 8.816 3.6.245 11.626.246 15.23 0 3.897-.266 4.356-2.62 4.385-8.816-.029-6.185-.484-8.549-4.385-8.816zm-10.615 12.816v-8l8 3.993-8 4.007z" />
            </svg>
        </div>
      )}

      {/* Overlay Gradient */}
      <div className="absolute inset-0 bg-black/20 group-hover:bg-black/10 transition-colors" />

      {/* Play Button */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="w-16 h-16 md:w-20 md:h-20 bg-white/90 dark:bg-black/60 rounded-full flex items-center justify-center backdrop-blur-sm shadow-xl group-hover:scale-110 transition-transform duration-300 group-hover:bg-white dark:group-hover:bg-black/80">
          <svg 
            className="w-8 h-8 md:w-10 md:h-10 text-indigo-600 dark:text-white ml-1" 
            fill="currentColor" 
            viewBox="0 0 24 24"
          >
            <path d="M8 5v14l11-7z" />
          </svg>
        </div>
      </div>

      {/* Title Label */}
      <div className="absolute bottom-4 left-4 right-4 group-hover:bottom-5 transition-all">
        <span className="inline-block px-3 py-1 bg-black/60 backdrop-blur-md text-white text-xs font-semibold rounded-lg shadow-sm font-[family-name:var(--font-montserrat)]">
          {title}
        </span>
      </div>
    </div>
  );
}
