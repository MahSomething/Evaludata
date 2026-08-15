"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { z } from "zod";
import { logger } from "@/lib/logger";

const loginSchema = z.object({
  email: z.string().email("Email invalido"),
  password: z.string().min(12, "Password deve ter no minimo 12 caracteres"),
});

export type LoginState = {
  success: boolean;
  error: string | null;
  data: null;
};

// Rate limiting simples em memoria (para MVP; em producao usar Redis/upstash)
const loginAttempts = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const windowMs = 15 * 60 * 1000; // 15 minutos
  const maxAttempts = 5;

  const record = loginAttempts.get(ip);
  if (!record || now > record.resetAt) {
    loginAttempts.set(ip, { count: 1, resetAt: now + windowMs });
    return true;
  }

  if (record.count >= maxAttempts) {
    return false;
  }

  record.count++;
  return true;
}

export async function login(prevState: LoginState, formData: FormData): Promise<LoginState> {
  const ip = "unknown"; // Em producao, extrair de headers ou usar middleware

  if (!checkRateLimit(ip)) {
    logger.warn("Rate limit exceeded for login", { ip });
    return { success: false, error: "Muitas tentativas. Tente novamente mais tarde.", data: null };
  }

  const validated = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });

  if (!validated.success) {
    return {
      success: false,
      error: "Dados invalidos. Verifique o formulario.",
      data: null,
    };
  }

  const { email, password } = validated.data;
  const supabase = await createClient();

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    logger.warn("Login failed", { email, error: error.message });
    return {
      success: false,
      error: "Email ou palavra-passe incorretos.",
      data: null,
    };
  }

  logger.info("Login successful", { email });
  revalidatePath("/", "layout");
  redirect("/");
}

export async function logout(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath("/", "layout");
  redirect("/login");
}