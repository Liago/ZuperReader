import { redirect } from 'next/navigation';

// Friends were merged into "Shared with me" during the web revamp (README §6).
// Keep the old route working by redirecting to the merged page.
export default function FriendsPage() {
	redirect('/shared');
}
