'use client';

import { useState, useEffect } from 'react';
import { addComment, getComments, deleteComment, updateComment } from '@/lib/api';
import type { Comment } from '@/lib/supabase';

interface CommentsSectionProps {
	articleId: string;
	userId: string;
	initialCommentCount: number;
}

export default function CommentsSection({ articleId, userId, initialCommentCount }: CommentsSectionProps) {
	const [comments, setComments] = useState<Comment[]>([]);
	const [newComment, setNewComment] = useState('');
	const [loading, setLoading] = useState(false);
	const [editingCommentId, setEditingCommentId] = useState<string | null>(null);
	const [editContent, setEditContent] = useState('');

	useEffect(() => {
		loadComments();
	}, [articleId]);

	const loadComments = async () => {
		try {
			const data = await getComments(articleId);
			setComments(data);
		} catch (error) {
			console.error('Error loading comments:', error);
		}
	};

	const handleAddComment = async (e: React.FormEvent) => {
		e.preventDefault();
		if (!newComment.trim() || loading) return;

		setLoading(true);
		try {
			const comment = await addComment(articleId, userId, newComment);
			setComments([comment, ...comments]);
			setNewComment('');
		} catch (error) {
			console.error('Error adding comment:', error);
			alert('Failed to add comment');
		} finally {
			setLoading(false);
		}
	};

	const handleDeleteComment = async (commentId: string) => {
		if (!confirm('Are you sure you want to delete this comment?')) return;

		try {
			await deleteComment(commentId, articleId);
			setComments(comments.filter(c => c.id !== commentId));
		} catch (error) {
			console.error('Error deleting comment:', error);
			alert('Failed to delete comment');
		}
	};

	const handleEditComment = async (commentId: string) => {
		if (!editContent.trim()) return;

		try {
			const updatedComment = await updateComment(commentId, editContent);
			setComments(comments.map(c => c.id === commentId ? updatedComment : c));
			setEditingCommentId(null);
			setEditContent('');
		} catch (error) {
			console.error('Error updating comment:', error);
			alert('Failed to update comment');
		}
	};

	const startEditing = (comment: Comment) => {
		setEditingCommentId(comment.id);
		setEditContent(comment.content);
	};

	const cancelEditing = () => {
		setEditingCommentId(null);
		setEditContent('');
	};

	return (
		<div className="mt-8 border-t pt-8">
			<h2 className="text-2xl font-bold mb-6">
				Comments ({comments.length})
			</h2>

			{/* Add Comment Form */}
			<form onSubmit={handleAddComment} className="mb-8">
				<textarea
					value={newComment}
					onChange={(e) => setNewComment(e.target.value)}
					placeholder="Write a comment..."
					className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
					rows={3}
					disabled={loading}
				/>
				<div className="mt-2 flex justify-end">
					<button
						type="submit"
						disabled={loading || !newComment.trim()}
						className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
					>
						{loading ? 'Posting...' : 'Post Comment'}
					</button>
				</div>
			</form>

			{/* Comments List */}
			<div className="space-y-4">
				{comments.length === 0 ? (
					<p className="text-gray-500 text-center py-8">No comments yet. Be the first to comment!</p>
				) : (
					comments.map((comment) => (
						<div key={comment.id} className="bg-gray-50 rounded-lg p-4">
							<div className="flex items-start justify-between mb-2">
								<div className="flex-1">
									<p className="text-sm text-gray-500">
										{new Date(comment.created_at).toLocaleDateString('en-US', {
											year: 'numeric',
											month: 'long',
											day: 'numeric',
											hour: '2-digit',
											minute: '2-digit'
										})}
									</p>
								</div>
								{comment.user_id === userId && (
									<div className="flex gap-2">
										<button
											onClick={() => startEditing(comment)}
											className="text-blue-600 hover:text-blue-800 text-sm font-medium"
										>
											Edit
										</button>
										<button
											onClick={() => handleDeleteComment(comment.id)}
											className="text-red-600 hover:text-red-800 text-sm font-medium"
										>
											Delete
										</button>
									</div>
								)}
							</div>

							{editingCommentId === comment.id ? (
								<div className="mt-2">
									<textarea
										value={editContent}
										onChange={(e) => setEditContent(e.target.value)}
										className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
										rows={3}
									/>
									<div className="mt-2 flex gap-2">
										<button
											onClick={() => handleEditComment(comment.id)}
											className="px-4 py-1 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm"
										>
											Save
										</button>
										<button
											onClick={cancelEditing}
											className="px-4 py-1 bg-gray-300 text-gray-700 rounded hover:bg-gray-400 text-sm"
										>
											Cancel
										</button>
									</div>
								</div>
							) : (
								<p className="text-gray-800 whitespace-pre-wrap">{comment.content}</p>
							)}
						</div>
					))
				)}
			</div>
		</div>
	);
}
