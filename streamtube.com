import React, { useState, useEffect, useMemo } from 'react';
import { initializeApp } from 'firebase/app';
import { 
  getAuth, 
  signInAnonymously, 
  signInWithCustomToken, 
  onAuthStateChanged, 
  signOut 
} from 'firebase/auth';
import { 
  getFirestore, 
  collection, 
  addDoc, 
  query, 
  onSnapshot, 
  orderBy, 
  serverTimestamp, 
  doc, 
  updateDoc, 
  increment, 
  getDoc 
} from 'firebase/firestore';
import { 
  Play, 
  Upload, 
  Search, 
  Menu, 
  User, 
  Heart, 
  MessageCircle, 
  Share2, 
  MoreVertical, 
  X, 
  Loader2,
  Film,
  Home
} from 'lucide-react';

// --- Firebase Configuration ---
const firebaseConfig = JSON.parse(__firebase_config);
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id';

// --- Components ---

const Navbar = ({ user, onUploadClick, onHomeClick, searchTerm, setSearchTerm }) => (
  <nav className="sticky top-0 z-50 bg-[#1f1f1f] border-b border-[#333] px-4 py-3 flex items-center justify-between shadow-md">
    <div className="flex items-center gap-4">
      <button className="p-2 hover:bg-[#333] rounded-full text-white lg:hidden">
        <Menu size={24} />
      </button>
      <div 
        onClick={onHomeClick}
        className="flex items-center gap-1 cursor-pointer group"
      >
        <div className="bg-red-600 text-white p-1 rounded-lg group-hover:bg-red-500 transition-colors">
          <Film size={20} fill="currentColor" />
        </div>
        <span className="text-xl font-bold text-white tracking-tight hidden sm:block">
          Stream<span className="text-red-500">Tube</span>
        </span>
      </div>
    </div>

    <div className="flex-1 max-w-xl mx-4 hidden sm:block">
      <div className="relative">
        <input
          type="text"
          placeholder="Search videos..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full bg-[#121212] border border-[#333] text-white px-4 py-2 pl-10 rounded-full focus:outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all"
        />
        <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
      </div>
    </div>

    <div className="flex items-center gap-3">
      <button className="sm:hidden p-2 text-white">
        <Search size={24} />
      </button>
      
      {user ? (
        <>
          <button 
            onClick={onUploadClick}
            className="hidden sm:flex items-center gap-2 bg-[#333] hover:bg-[#444] text-white px-4 py-2 rounded-full transition-all font-medium text-sm"
          >
            <Upload size={18} />
            <span>Upload</span>
          </button>
          <button 
            onClick={onUploadClick}
            className="sm:hidden p-2 text-white hover:bg-[#333] rounded-full"
          >
            <Upload size={24} />
          </button>
          <div className="w-8 h-8 bg-gradient-to-br from-red-500 to-pink-600 rounded-full flex items-center justify-center text-white font-bold cursor-pointer" title={user.uid}>
            {user.uid.slice(0, 1).toUpperCase()}
          </div>
        </>
      ) : (
        <button className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-full font-medium transition-colors">
          Sign In
        </button>
      )}
    </div>
  </nav>
);

const Sidebar = ({ isOpen }) => (
  <aside className={`fixed left-0 top-16 h-[calc(100vh-64px)] w-60 bg-[#1f1f1f] border-r border-[#333] overflow-y-auto transform transition-transform duration-300 ease-in-out ${isOpen ? 'translate-x-0' : '-translate-x-full'} lg:translate-x-0 lg:static hidden lg:block`}>
    <div className="p-4 space-y-2">
      <SidebarItem icon={<Home size={20} />} label="Home" active />
      <SidebarItem icon={<Heart size={20} />} label="Liked Videos" />
      <SidebarItem icon={<User size={20} />} label="Your Channel" />
      <div className="border-t border-[#333] my-4 pt-4">
        <h3 className="text-gray-400 text-xs font-bold uppercase px-4 mb-2">Subscriptions</h3>
        <p className="px-4 text-sm text-gray-500 italic">Sign in to see subscriptions</p>
      </div>
    </div>
  </aside>
);

const SidebarItem = ({ icon, label, active }) => (
  <button className={`w-full flex items-center gap-4 px-4 py-3 rounded-xl transition-colors ${active ? 'bg-[#333] text-white font-medium' : 'text-gray-400 hover:bg-[#2a2a2a] hover:text-white'}`}>
    {icon}
    <span className="text-sm">{label}</span>
  </button>
);

const VideoCard = ({ video, onClick }) => (
  <div onClick={() => onClick(video)} className="group cursor-pointer flex flex-col gap-2">
    <div className="relative aspect-video bg-[#111] rounded-xl overflow-hidden">
      <img 
        src={video.thumbnail || "https://placehold.co/600x400/1a1a1a/FFF?text=No+Thumbnail"} 
        alt={video.title} 
        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
        onError={(e) => { e.target.src = 'https://placehold.co/600x400/1a1a1a/FFF?text=Error'; }}
      />
      <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors" />
      <span className="absolute bottom-2 right-2 bg-black/80 text-white text-xs px-1.5 py-0.5 rounded font-medium">
        {video.duration || "0:00"}
      </span>
      <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
        <div className="bg-red-600 p-3 rounded-full shadow-lg transform scale-90 group-hover:scale-100 transition-transform">
          <Play size={24} fill="white" className="text-white ml-1" />
        </div>
      </div>
    </div>
    <div className="flex gap-3 mt-1">
      <div className="w-9 h-9 rounded-full bg-gray-700 flex-shrink-0" />
      <div className="flex flex-col">
        <h3 className="text-white font-semibold text-sm line-clamp-2 leading-tight group-hover:text-red-500 transition-colors">
          {video.title}
        </h3>
        <span className="text-gray-400 text-xs mt-1">{video.channelName || "Anonymous"}</span>
        <div className="flex items-center text-gray-400 text-xs gap-1">
          <span>{video.views || 0} views</span>
          <span>•</span>
          <span>{new Date(video.createdAt?.seconds * 1000).toLocaleDateString()}</span>
        </div>
      </div>
    </div>
  </div>
);

const VideoPlayer = ({ video, onClose, user }) => {
  const [likes, setLikes] = useState(video.likes || 0);
  const [hasLiked, setHasLiked] = useState(false);
  const [comments, setComments] = useState([]);
  const [newComment, setNewComment] = useState("");

  // Real-time comments listener
  useEffect(() => {
    if (!video.id) return;
    const q = query(
      collection(db, 'artifacts', appId, 'public', 'data', `comments_${video.id}`),
      orderBy('createdAt', 'desc')
    );
    const unsubscribe = onSnapshot(q, (snapshot) => {
      setComments(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    }, (err) => console.error("Comments error:", err));
    return () => unsubscribe();
  }, [video.id]);

  const handleLike = async () => {
    if (!user) return;
    const videoRef = doc(db, 'artifacts', appId, 'public', 'data', 'videos', video.id);
    
    // Optimistic UI
    if (hasLiked) {
      setLikes(l => l - 1);
      setHasLiked(false);
      await updateDoc(videoRef, { likes: increment(-1) });
    } else {
      setLikes(l => l + 1);
      setHasLiked(true);
      await updateDoc(videoRef, { likes: increment(1) });
    }
  };

  const handlePostComment = async (e) => {
    e.preventDefault();
    if (!newComment.trim() || !user) return;

    try {
      await addDoc(collection(db, 'artifacts', appId, 'public', 'data', `comments_${video.id}`), {
        text: newComment,
        userId: user.uid,
        username: user.displayName || "User " + user.uid.slice(0, 4),
        createdAt: serverTimestamp(),
      });
      setNewComment("");
    } catch (err) {
      console.error("Error posting comment:", err);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] bg-[#0f0f0f] overflow-y-auto">
      <div className="max-w-[1600px] mx-auto min-h-screen flex flex-col lg:flex-row">
        {/* Main Content */}
        <div className="flex-1 p-4 lg:p-6">
          {/* Header/Close (Mobile) */}
          <div className="flex justify-between items-center mb-4 lg:hidden">
             <button onClick={onClose} className="flex items-center gap-2 text-gray-300">
               <X size={20} /> Back
             </button>
          </div>

          {/* Player Container */}
          <div className="w-full aspect-video bg-black rounded-xl overflow-hidden shadow-2xl relative group">
            {video.videoUrl.includes('youtube.com') || video.videoUrl.includes('youtu.be') ? (
               <iframe 
                 src={video.videoUrl.replace('watch?v=', 'embed/')} 
                 className="w-full h-full" 
                 allowFullScreen 
                 title={video.title}
                 frameBorder="0"
               />
            ) : (
              <video 
                src={video.videoUrl} 
                controls 
                autoPlay 
                className="w-full h-full object-contain" 
                poster={video.thumbnail}
              >
                Your browser does not support the video tag.
              </video>
            )}
            <button 
              onClick={onClose}
              className="absolute top-4 right-4 bg-black/50 hover:bg-black/70 p-2 rounded-full text-white opacity-0 group-hover:opacity-100 transition-opacity hidden lg:block"
            >
              <X size={24} />
            </button>
          </div>

          {/* Info Section */}
          <div className="mt-4">
            <h1 className="text-xl md:text-2xl font-bold text-white mb-2">{video.title}</h1>
            
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-[#333]">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-gradient-to-r from-purple-500 to-red-500" />
                <div>
                  <h4 className="text-white font-semibold">{video.channelName || "Anonymous Channel"}</h4>
                  <p className="text-gray-400 text-xs">1.2K subscribers</p>
                </div>
                <button className="ml-4 bg-white text-black px-4 py-1.5 rounded-full font-medium hover:bg-gray-200 transition-colors">
                  Subscribe
                </button>
              </div>

              <div className="flex items-center gap-2">
                <div className="flex items-center bg-[#272727] rounded-full overflow-hidden">
                  <button 
                    onClick={handleLike}
                    className={`flex items-center gap-2 px-4 py-2 hover:bg-[#3f3f3f] transition-colors border-r border-[#3f3f3f] ${hasLiked ? 'text-red-500' : 'text-white'}`}
                  >
                    <Heart size={20} fill={hasLiked ? "currentColor" : "none"} />
                    <span className="font-medium">{likes}</span>
                  </button>
                  <button className="px-4 py-2 hover:bg-[#3f3f3f] text-white transition-colors">
                    <MoreVertical size={20} className="transform rotate-90" />
                  </button>
                </div>
                <button className="flex items-center gap-2 bg-[#272727] hover:bg-[#3f3f3f] text-white px-4 py-2 rounded-full transition-colors">
                  <Share2 size={20} />
                  <span className="hidden sm:inline">Share</span>
                </button>
              </div>
            </div>

            <div className="mt-4 bg-[#272727] p-3 rounded-xl hover:bg-[#333] transition-colors cursor-pointer">
               <p className="text-white text-sm font-medium mb-1">
                 {video.views || 0} views • {new Date(video.createdAt?.seconds * 1000).toLocaleDateString()}
               </p>
               <p className="text-gray-300 text-sm whitespace-pre-wrap">{video.description || "No description provided."}</p>
            </div>
            
            {/* Comments Section */}
            <div className="mt-6">
              <h3 className="text-white font-bold text-lg mb-4 flex items-center gap-2">
                {comments.length} Comments
              </h3>
              
              {user && (
                <form onSubmit={handlePostComment} className="flex gap-4 mb-6">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-red-500 to-pink-600 flex-shrink-0" />
                  <div className="flex-1">
                    <input 
                      value={newComment}
                      onChange={(e) => setNewComment(e.target.value)}
                      placeholder="Add a comment..."
                      className="w-full bg-transparent border-b border-[#333] text-white pb-2 focus:border-white focus:outline-none transition-colors"
                    />
                    <div className="flex justify-end gap-2 mt-2">
                      <button 
                        type="button" 
                        onClick={() => setNewComment("")}
                        className="px-4 py-2 text-white hover:bg-[#333] rounded-full text-sm font-medium"
                      >
                        Cancel
                      </button>
                      <button 
                        type="submit"
                        disabled={!newComment.trim()}
                        className="px-4 py-2 bg-[#3ea6ff] text-black hover:bg-[#65b8ff] disabled:bg-[#333] disabled:text-gray-500 rounded-full text-sm font-medium transition-colors"
                      >
                        Comment
                      </button>
                    </div>
                  </div>
                </form>
              )}

              <div className="space-y-4">
                {comments.map((comment) => (
                  <div key={comment.id} className="flex gap-3">
                    <div className="w-8 h-8 rounded-full bg-gray-700 flex-shrink-0" />
                    <div>
                      <div className="flex items-baseline gap-2">
                        <span className="text-white text-sm font-semibold">{comment.username}</span>
                        <span className="text-gray-500 text-xs">Just now</span>
                      </div>
                      <p className="text-white text-sm mt-1">{comment.text}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Sidebar Recommendations (Static for demo) */}
        <div className="lg:w-[400px] p-4 lg:p-6 lg:border-l border-[#333]">
           <h3 className="text-white font-bold mb-4">Up Next</h3>
           <div className="flex flex-col gap-3">
             {[1, 2, 3, 4, 5].map((i) => (
               <div key={i} className="flex gap-2 cursor-pointer group">
                  <div className="w-40 aspect-video bg-[#222] rounded-lg overflow-hidden relative">
                    <div className="absolute inset-0 bg-red-500/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </div>
                  <div className="flex-1">
                    <h4 className="text-white text-sm font-semibold line-clamp-2 group-hover:text-red-400">Recommended Video {i}</h4>
                    <p className="text-gray-400 text-xs mt-1">Cool Channel</p>
                    <p className="text-gray-400 text-xs">10K views • 2 days ago</p>
                  </div>
               </div>
             ))}
           </div>
        </div>
      </div>
    </div>
  );
};

const UploadModal = ({ isOpen, onClose, user }) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    videoUrl: '',
    thumbnail: '',
  });

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!user) return;
    setLoading(true);

    try {
      // Validate inputs lightly
      if (!formData.title || !formData.videoUrl) throw new Error("Title and URL required");

      await addDoc(collection(db, 'artifacts', appId, 'public', 'data', 'videos'), {
        ...formData,
        userId: user.uid,
        channelName: user.displayName || "User " + user.uid.slice(0, 4),
        views: 0,
        likes: 0,
        createdAt: serverTimestamp(),
        duration: "4:20" // Mock duration
      });
      onClose();
      setFormData({ title: '', description: '', videoUrl: '', thumbnail: '' });
    } catch (err) {
      console.error("Upload error", err);
      alert("Failed to upload. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-[#1f1f1f] w-full max-w-2xl rounded-2xl shadow-2xl border border-[#333] flex flex-col max-h-[90vh]">
        <div className="flex justify-between items-center p-4 border-b border-[#333]">
          <h2 className="text-white text-xl font-bold">Upload Video</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white">
            <X size={24} />
          </button>
        </div>
        
        <form onSubmit={handleSubmit} className="p-6 overflow-y-auto space-y-6">
          <div className="bg-[#121212] p-4 rounded-xl border border-[#333] flex flex-col items-center justify-center gap-2 text-center">
             <div className="w-16 h-16 bg-[#222] rounded-full flex items-center justify-center mb-2">
               <Upload size={32} className="text-gray-400" />
             </div>
             <p className="text-white font-medium">Add Video URL</p>
             <p className="text-gray-500 text-xs max-w-sm">
               For this demo, please paste a direct .mp4 URL or a generic placeholder URL. Storage buckets are simulated.
             </p>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-gray-400 text-sm mb-1">Title</label>
              <input 
                required
                type="text"
                placeholder="Video Title"
                value={formData.title}
                onChange={e => setFormData({...formData, title: e.target.value})}
                className="w-full bg-[#121212] border border-[#333] text-white p-3 rounded-lg focus:border-red-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-gray-400 text-sm mb-1">Description</label>
              <textarea 
                rows={4}
                placeholder="Tell viewers about your video"
                value={formData.description}
                onChange={e => setFormData({...formData, description: e.target.value})}
                className="w-full bg-[#121212] border border-[#333] text-white p-3 rounded-lg focus:border-red-500 focus:outline-none resize-none"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
               <div>
                  <label className="block text-gray-400 text-sm mb-1">Video URL (MP4/WebM)</label>
                  <input 
                    required
                    type="url"
                    placeholder="https://example.com/video.mp4"
                    value={formData.videoUrl}
                    onChange={e => setFormData({...formData, videoUrl: e.target.value})}
                    className="w-full bg-[#121212] border border-[#333] text-white p-3 rounded-lg focus:border-red-500 focus:outline-none text-sm"
                  />
               </div>
               <div>
                  <label className="block text-gray-400 text-sm mb-1">Thumbnail URL</label>
                  <input 
                    type="url"
                    placeholder="https://example.com/image.jpg"
                    value={formData.thumbnail}
                    onChange={e => setFormData({...formData, thumbnail: e.target.value})}
                    className="w-full bg-[#121212] border border-[#333] text-white p-3 rounded-lg focus:border-red-500 focus:outline-none text-sm"
                  />
               </div>
            </div>
          </div>

          <div className="flex justify-end pt-4 border-t border-[#333]">
             <button 
               type="submit" 
               disabled={loading}
               className="bg-red-600 hover:bg-red-700 text-white px-8 py-2 rounded-full font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
             >
               {loading && <Loader2 size={18} className="animate-spin" />}
               {loading ? 'Uploading...' : 'Upload Video'}
             </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default function App() {
  const [user, setUser] = useState(null);
  const [videos, setVideos] = useState([]);
  const [selectedVideo, setSelectedVideo] = useState(null);
  const [isUploadOpen, setIsUploadOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [isSidebarOpen, setIsSidebarOpen] = useState(false); // Mobile sidebar state

  // Auth Init
  useEffect(() => {
    const initAuth = async () => {
      if (typeof __initial_auth_token !== 'undefined' && __initial_auth_token) {
        await signInWithCustomToken(auth, __initial_auth_token);
      } else {
        await signInAnonymously(auth);
      }
    };
    initAuth();
    return onAuthStateChanged(auth, setUser);
  }, []);

  // Fetch Videos
  useEffect(() => {
    if (!user) return;
    const q = query(
      collection(db, 'artifacts', appId, 'public', 'data', 'videos'),
      orderBy('createdAt', 'desc')
    );
    const unsubscribe = onSnapshot(q, 
      (snapshot) => {
        setVideos(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      },
      (error) => console.error("Firestore error:", error)
    );
    return () => unsubscribe();
  }, [user]);

  const filteredVideos = useMemo(() => {
    return videos.filter(v => 
      v.title.toLowerCase().includes(searchTerm.toLowerCase()) || 
      v.description?.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [videos, searchTerm]);

  return (
    <div className="min-h-screen bg-[#0f0f0f] text-white font-sans selection:bg-red-500 selection:text-white">
      <Navbar 
        user={user} 
        onUploadClick={() => setIsUploadOpen(true)}
        searchTerm={searchTerm}
        setSearchTerm={setSearchTerm}
        onHomeClick={() => setSelectedVideo(null)}
      />
      
      <div className="flex">
        <Sidebar isOpen={isSidebarOpen} />
        
        <main className="flex-1 p-4 lg:p-6 overflow-hidden">
          {/* Categories / Tags (Static) */}
          <div className="flex gap-3 overflow-x-auto pb-4 mb-2 scrollbar-hide">
            {['All', 'Live', 'Gaming', 'Music', 'Tech', 'Nature', 'Recently Uploaded'].map((tag, i) => (
              <button 
                key={tag}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium whitespace-nowrap transition-colors ${i === 0 ? 'bg-white text-black' : 'bg-[#272727] text-white hover:bg-[#3f3f3f]'}`}
              >
                {tag}
              </button>
            ))}
          </div>

          {filteredVideos.length === 0 ? (
             <div className="flex flex-col items-center justify-center py-20 text-center">
                <div className="w-24 h-24 bg-[#1f1f1f] rounded-full flex items-center justify-center mb-4">
                  <Film size={40} className="text-gray-600" />
                </div>
                <h2 className="text-xl font-bold text-gray-300">No videos yet</h2>
                <p className="text-gray-500 mt-2 max-w-md">Be the first to upload content to StreamTube! Click the Upload button above.</p>
                <button 
                  onClick={() => setIsUploadOpen(true)}
                  className="mt-6 text-red-500 font-medium hover:text-red-400"
                >
                  Upload a video now
                </button>
             </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-x-4 gap-y-8">
              {filteredVideos.map(video => (
                <VideoCard 
                  key={video.id} 
                  video={video} 
                  onClick={setSelectedVideo} 
                />
              ))}
            </div>
          )}
        </main>
      </div>

      {selectedVideo && (
        <VideoPlayer 
          video={selectedVideo} 
          onClose={() => setSelectedVideo(null)}
          user={user}
        />
      )}

      <UploadModal 
        isOpen={isUploadOpen} 
        onClose={() => setIsUploadOpen(false)} 
        user={user}
      />
    </div>
  );
}
