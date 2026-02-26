import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Visconde Backend",
  description: "API backend em Next.js com Prisma e PostgreSQL",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
