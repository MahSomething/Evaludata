export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Papel = "super_admin" | "admin" | "contabilista" | "cliente";
export type EstadoDocumento = "ativo" | "pendente" | "rejeitado" | "arquivado" | "eliminado";
export type AcaoLog = "visualizar" | "download" | "upload" | "aprovar" | "rejeitar" | "eliminar";

export interface Database {
  public: {
    Tables: {
      organizacoes: {
        Row: {
          id: string;
          nome: string;
          nif: string;
          owner_id: string | null;
          pode_registar_clientes: boolean;
          ativa: boolean;
          criada_em: string;
          atualizada_em: string;
        };
        Insert: {
          id?: string;
          nome: string;
          nif: string;
          owner_id?: string | null;
          pode_registar_clientes?: boolean;
          ativa?: boolean;
          criada_em?: string;
          atualizada_em?: string;
        };
        Update: Partial<Database["public"]["Tables"]["organizacoes"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "organizacoes_owner_id_fkey";
            columns: ["owner_id"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          }
        ];
      };
      utilizadores: {
        Row: {
          id: string;
          organizacao_id: string;
          email: string;
          nome: string;
          papel: Papel;
          telemovel: string | null;
          ativo: boolean;
          criado_em: string;
          atualizado_em: string;
          criado_por: string | null;
        };
        Insert: {
          id?: string;
          organizacao_id: string;
          email: string;
          nome: string;
          papel: Papel;
          telemovel?: string | null;
          ativo?: boolean;
          criado_em?: string;
          atualizado_em?: string;
          criado_por?: string | null;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["utilizadores"]["Row"], "id">>;
        Relationships: [
          {
            foreignKeyName: "utilizadores_organizacao_id_fkey";
            columns: ["organizacao_id"];
            referencedRelation: "organizacoes";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "utilizadores_criado_por_fkey";
            columns: ["criado_por"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          }
        ];
      };
      empresas: {
        Row: {
          id: string;
          organizacao_id: string;
          nome: string;
          nuit: string;
          contacto: string | null;
          ativa: boolean;
          criada_em: string;
          atualizada_em: string;
        };
        Insert: {
          id?: string;
          organizacao_id: string;
          nome: string;
          nuit: string;
          contacto?: string | null;
          ativa?: boolean;
          criada_em?: string;
          atualizada_em?: string;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["empresas"]["Row"], "id">>;
        Relationships: [
          {
            foreignKeyName: "empresas_organizacao_id_fkey";
            columns: ["organizacao_id"];
            referencedRelation: "organizacoes";
            referencedColumns: ["id"];
          }
        ];
      };
      contabilista_empresas: {
        Row: {
          id: string;
          contabilista_id: string;
          empresa_id: string;
          atribuido_por: string | null;
          criado_em: string;
        };
        Insert: {
          id?: string;
          contabilista_id: string;
          empresa_id: string;
          atribuido_por?: string | null;
          criado_em?: string;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["contabilista_empresas"]["Row"], "id">>;
        Relationships: [
          {
            foreignKeyName: "contabilista_empresas_contabilista_id_fkey";
            columns: ["contabilista_id"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "contabilista_empresas_empresa_id_fkey";
            columns: ["empresa_id"];
            referencedRelation: "empresas";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "contabilista_empresas_atribuido_por_fkey";
            columns: ["atribuido_por"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          }
        ];
      };
      cliente_empresas: {
        Row: {
          id: string;
          cliente_id: string;
          empresa_id: string;
          atribuido_por: string | null;
          criado_em: string;
        };
        Insert: {
          id?: string;
          cliente_id: string;
          empresa_id: string;
          atribuido_por?: string | null;
          criado_em?: string;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["cliente_empresas"]["Row"], "id">>;
        Relationships: [
          {
            foreignKeyName: "cliente_empresas_cliente_id_fkey";
            columns: ["cliente_id"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "cliente_empresas_empresa_id_fkey";
            columns: ["empresa_id"];
            referencedRelation: "empresas";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "cliente_empresas_atribuido_por_fkey";
            columns: ["atribuido_por"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          }
        ];
      };
      documentos: {
        Row: {
          id: string;
          empresa_id: string;
          organizacao_id: string;
          tipo_documento: string;
          ano: number;
          periodo: string | null;
          ficheiro_url: string;
          ficheiro_nome: string;
          ficheiro_tamanho: number;
          versao: number;
          documento_pai_id: string | null;
          estado: EstadoDocumento;
          substitui_id: string | null;
          data_soft_delete: string | null;
          metadados: Json;
          notas: string | null;
          criado_por: string;
          atualizado_por: string | null;
          criado_em: string;
          atualizado_em: string;
        };
        Insert: {
          id?: string;
          empresa_id: string;
          organizacao_id: string;
          tipo_documento: string;
          ano: number;
          periodo?: string | null;
          ficheiro_url: string;
          ficheiro_nome: string;
          ficheiro_tamanho: number;
          versao?: number;
          documento_pai_id?: string | null;
          estado?: EstadoDocumento;
          substitui_id?: string | null;
          data_soft_delete?: string | null;
          metadados?: Json;
          notas?: string | null;
          criado_por: string;
          atualizado_por?: string | null;
          criado_em?: string;
          atualizado_em?: string;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["documentos"]["Row"], "id">>;
        Relationships: [
          {
            foreignKeyName: "documentos_empresa_id_fkey";
            columns: ["empresa_id"];
            referencedRelation: "empresas";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "documentos_organizacao_id_fkey";
            columns: ["organizacao_id"];
            referencedRelation: "organizacoes";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "documentos_documento_pai_id_fkey";
            columns: ["documento_pai_id"];
            referencedRelation: "documentos";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "documentos_substitui_id_fkey";
            columns: ["substitui_id"];
            referencedRelation: "documentos";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "documentos_criado_por_fkey";
            columns: ["criado_por"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "documentos_atualizado_por_fkey";
            columns: ["atualizado_por"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          }
        ];
      };
      log_acessos: {
        Row: {
          id: string;
          documento_id: string;
          utilizador_id: string | null;
          acao: AcaoLog;
          ip: string | null;
          user_agent: string | null;
          criado_em: string;
        };
        Insert: {
          id?: string;
          documento_id: string;
          utilizador_id?: string | null;
          acao: AcaoLog;
          ip?: string | null;
          user_agent?: string | null;
          criado_em?: string;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["log_acessos"]["Row"], "id">>;
        Relationships: [
          {
            foreignKeyName: "log_acessos_documento_id_fkey";
            columns: ["documento_id"];
            referencedRelation: "documentos";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "log_acessos_utilizador_id_fkey";
            columns: ["utilizador_id"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          }
        ];
      };
      otp_codes: {
        Row: {
          id: string;
          utilizador_id: string;
          telemovel: string;
          codigo: string;
          expira_em: string;
          tentativas: number;
          utilizado: boolean;
          criado_em: string;
        };
        Insert: {
          id?: string;
          utilizador_id: string;
          telemovel: string;
          codigo: string;
          expira_em: string;
          tentativas?: number;
          utilizado?: boolean;
          criado_em?: string;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["otp_codes"]["Row"], "id">>;
        Relationships: [
          {
            foreignKeyName: "otp_codes_utilizador_id_fkey";
            columns: ["utilizador_id"];
            referencedRelation: "utilizadores";
            referencedColumns: ["id"];
          }
        ];
      };
      tipos_documento: {
        Row: {
          id: string;
          nome: string;
          descricao: string | null;
          ativo: boolean;
          criado_em: string;
          atualizado_em: string;
        };
        Insert: {
          id?: string;
          nome: string;
          descricao?: string | null;
          ativo?: boolean;
          criado_em?: string;
          atualizado_em?: string;
        };
        Update: Partial<Omit<Database["public"]["Tables"]["tipos_documento"]["Row"], "id">>;
        Relationships: [];
      };
    };
    Views: { [_ in never]: never };
    Functions: { [_ in never]: never };
    Enums: { [_ in never]: never };
    CompositeTypes: { [_ in never]: never };
  };
}

export type Tables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Row"];
export type InsertTables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Insert"];
export type UpdateTables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Update"];

export type Organizacao = Tables<"organizacoes">;
export type Utilizador = Tables<"utilizadores">;
export type Empresa = Tables<"empresas">;
export type ContabilistaEmpresa = Tables<"contabilista_empresas">;
export type ClienteEmpresa = Tables<"cliente_empresas">;
export type Documento = Tables<"documentos">;
export type LogAcesso = Tables<"log_acessos">;
export type OtpCode = Tables<"otp_codes">;
export type TipoDocumento = Tables<"tipos_documento">;
