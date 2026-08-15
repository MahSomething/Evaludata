import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { LoginForm } from "@/components/forms/login-form";

export default async function LoginPage() {
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
    <div className="w-full max-w-md p-6 bg-background rounded-lg shadow-lg border">
      <h1 className="text-2xl font-semibold text-center mb-6">Aceder a Plataforma</h1>
      <LoginForm />
    </div>
  );
}