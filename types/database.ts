export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  public: {
    Tables: {
      organizacoes: {
        Row: {
          id: string;
          nome: string;
          nuit: string;
          owner_id: string | null;
          pode_registar_clientes: boolean;
          ativa: boolean;
          criada_em: string;
          atualizada_em: string;
        };
        Insert: {
          id?: string;
          nome: string;
          nuit: string;
          owner_id?: string | null;
          pode_registar_clientes?: boolean;
          ativa?: boolean;
          criada_em?: string;
          atualizada_em?: string;
        };
        Update: Partial<Database["public"]["Tables"]["organizacoes"]["Insert"]>;
      };
      // Adicionar outras tabelas conforme gerado pelo supabase gen types
    };
  };
}
