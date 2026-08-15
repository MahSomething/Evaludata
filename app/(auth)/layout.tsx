import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function AuthLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (user) {
    const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;
    if (papel === "cliente") {
      redirect("/portal");
    }
    redirect("/");
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-muted/50">
      {children}
    </div>
  );
}