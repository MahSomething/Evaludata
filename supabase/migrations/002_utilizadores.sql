-- Migration: 002_utilizadores
-- Criação da tabela de utilizadores (todos os que têm login)
-- Tarefa: DB-002

-- ============================================
-- TIPO ENUM: papel
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'papel_enum') THEN
        CREATE TYPE public.papel_enum AS ENUM ('super_admin', 'admin', 'contabilista', 'cliente');
    END IF;
END $$;

-- ============================================
-- TABELA: utilizadores
-- ============================================

CREATE TABLE IF NOT EXISTS public.utilizadores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id UUID,
    email TEXT UNIQUE NOT NULL,
    nome TEXT NOT NULL,
    papel public.papel_enum NOT NULL DEFAULT 'contabilista',
    telemovel TEXT UNIQUE,
    ativo BOOLEAN NOT NULL DEFAULT true,
    criado_por UUID,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_utilizadores_organizacao
        FOREIGN KEY (organizacao_id)
        REFERENCES public.organizacoes(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_utilizadores_criado_por
        FOREIGN KEY (criado_por)
        REFERENCES public.utilizadores(id)
        ON DELETE SET NULL
);

-- Comentários
COMMENT ON TABLE public.utilizadores IS 'Todos os utilizadores do sistema (Super Admin, Admin, Contabilista, Cliente)';
COMMENT ON COLUMN public.utilizadores.id IS 'UUID — sincronizado com auth.users do Supabase';
COMMENT ON COLUMN public.utilizadores.organizacao_id IS 'NULL para Super Admin (acesso global)';
COMMENT ON COLUMN public.utilizadores.telemovel IS 'Obrigatório para clientes (login via OTP WhatsApp)';
COMMENT ON COLUMN public.utilizadores.criado_por IS 'Quem criou este utilizador (auditoria)';

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_utilizadores_organizacao ON public.utilizadores(organizacao_id);
CREATE INDEX IF NOT EXISTS idx_utilizadores_papel ON public.utilizadores(papel);
CREATE INDEX IF NOT EXISTS idx_utilizadores_ativo ON public.utilizadores(ativo);
CREATE INDEX IF NOT EXISTS idx_utilizadores_telemovel ON public.utilizadores(telemovel) WHERE telemovel IS NOT NULL;

-- ============================================
-- TRIGGER: atualizar updated_at
-- ============================================

CREATE TRIGGER trg_utilizadores_updated_at
    BEFORE UPDATE ON public.utilizadores
    FOR EACH ROW
    EXECUTE FUNCTION public.atualizar_updated_at();

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.utilizadores ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin vê todos
-- Admin vê todos da sua org (exceto Super Admin)
-- Contabilista e Cliente vêem apenas o próprio perfil
CREATE POLICY "utilizadores_select" ON public.utilizadores
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR id = (auth.jwt() ->> 'sub')::UUID
        OR (
            organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
            AND papel != 'super_admin'
        )
    );

-- Policy: INSERT
-- Super Admin pode criar qualquer um
-- Admin pode criar contabilistas e clientes da sua org
-- (se pode_registar_clientes for true para clientes)
CREATE POLICY "utilizadores_insert" ON public.utilizadores
    FOR INSERT WITH CHECK (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            (auth.jwt() ->> 'papel') = 'admin'
            AND organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND papel IN ('contabilista', 'cliente')
            AND (
                papel != 'cliente'
                OR EXISTS (
                    SELECT 1 FROM public.organizacoes o
                    WHERE o.id = organizacao_id
                    AND o.pode_registar_clientes = true
                )
            )
        )
    );

-- Policy: UPDATE
-- Super Admin pode atualizar tudo
-- Admin pode atualizar da sua org (exceto Super Admin)
-- Contabilista/Cliente podem atualizar apenas o próprio perfil (campos limitados)
CREATE POLICY "utilizadores_update" ON public.utilizadores
    FOR UPDATE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            id = (auth.jwt() ->> 'sub')::UUID
            AND papel IN ('contabilista', 'cliente')
        )
        OR (
            organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
            AND papel != 'super_admin'
        )
    );

-- Policy: DELETE
-- Apenas Super Admin (soft delete via ativo = false é preferido)
CREATE POLICY "utilizadores_delete" ON public.utilizadores
    FOR DELETE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
    );
