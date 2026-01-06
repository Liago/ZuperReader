import type { Metadata } from "next";
import { Geist, Geist_Mono, Roboto, Lato, Open_Sans, Ubuntu, Montserrat } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "../contexts/AuthContext";
import { ThemeProvider } from "../contexts/ThemeContext";
import { ReadingPreferencesProvider } from "../contexts/ReadingPreferencesContext";
import { FriendsProvider } from "../contexts/FriendsContext";
import { ArticlesProvider } from "../contexts/ArticlesContext";
import { ArticleFiltersProvider } from "../contexts/ArticleFiltersContext";
import { QueryProvider } from "../contexts/QueryProvider";

const geistSans = Geist({
	variable: "--font-geist-sans",
	subsets: ["latin"],
});

const geistMono = Geist_Mono({
	variable: "--font-geist-mono",
	subsets: ["latin"],
});

const roboto = Roboto({
	weight: ['300', '400', '500', '700'],
	variable: "--font-roboto",
	subsets: ["latin"],
});

const lato = Lato({
	weight: ['300', '400', '700', '900'],
	variable: "--font-lato",
	subsets: ["latin"],
});

const openSans = Open_Sans({
	variable: "--font-open-sans",
	subsets: ["latin"],
});

const ubuntu = Ubuntu({
	weight: ['300', '400', '500', '700'],
	variable: "--font-ubuntu",
	subsets: ["latin"],
});

const montserrat = Montserrat({
	weight: ['300', '400', '500', '600', '700'],
	variable: "--font-montserrat",
	subsets: ["latin"],
});

export const metadata: Metadata = {
	title: "SuperReader",
	description: "Save and read your favorite articles",
	manifest: "/manifest.json",
	appleWebApp: {
		capable: true,
		statusBarStyle: "default",
		title: "SuperReader",
	},
	formatDetection: {
		telephone: false,
	},
	other: {
		"mobile-web-app-capable": "yes",
	},
};

export default function RootLayout({
	children,
}: Readonly<{
	children: React.ReactNode;
}>) {
	return (
		<html lang="en">
			<body
				className={`${geistSans.variable} ${geistMono.variable} ${roboto.variable} ${lato.variable} ${openSans.variable} ${ubuntu.variable} ${montserrat.variable} antialiased`}
			>
				<QueryProvider>
					<AuthProvider>
						<ThemeProvider>
							<FriendsProvider>
								<ReadingPreferencesProvider>
									<ArticleFiltersProvider>
										<ArticlesProvider>
											{children}
										</ArticlesProvider>
									</ArticleFiltersProvider>
								</ReadingPreferencesProvider>
							</FriendsProvider>
						</ThemeProvider>
					</AuthProvider>
				</QueryProvider>
			</body>
		</html>
	);
}
