import type { Metadata } from 'next';
import './globals.css';
export const metadata:Metadata={title:'Followkind | Volunteer updates, followed through',description:'Record volunteer hours, review updates and keep family needs moving.'};
export default function RootLayout({children}:{children:React.ReactNode}) {return <html lang="en"><body>{children}</body></html>;}
