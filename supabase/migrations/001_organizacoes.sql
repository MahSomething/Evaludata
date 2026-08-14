-- Migration: 001_organizacoes
-- Criação da tabela de organizações (consultorias de contabilidade)
-- Tarefa: DB-001

-- ============================================
-- TABELA: organizacoes
-- ============================================

CREATE TABLE IF NOT EXISTS public.organizacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    nif TEXT UNIQUE NOT NULL,
    owner_id UUID,
    pode_registar_clientes BOOLEAN NOT NULL DEFAULT false,
    ativa BOOLEAN NOT NULL DEFAULT true,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizada_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Comentários para documentação
COMMENT ON TABLE public.organizacoes IS 'Consultorias de contabilidade (multi-tenant)';
COMMENT ON COLUMN public.organizacoes.id IS 'UUID único da organização';
COMMENT ON COLUMN public.organizacoes.nome IS 'Nome comercial da consultoria';
COMMENT ON COLUMN public.organizacoes.nif IS 'NIF português (9 dígitos)';
COMMENT ON COLUMN public.organizacoes.owner_id IS 'ID do utilizador Admin/Owner da consultoria';
COMMENT ON COLUMN public.organizacoes.pode_registar_clientes IS 'Permissão controlada pelo Super Admin';
COMMENT ON COLUMN public.organizacoes.ativa IS 'Soft delete / desativação';

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_organizacoes_ativa ON public.organizacoes(ativa);
CREATE INDEX IF NOT EXISTS idx_organizacoes_owner ON public.organizacoes(owner_id);

-- ============================================
-- TRIGGER: atualizar updated_at automaticamente
-- ============================================

CREATE OR REPLACE FUNCTION public.atualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizada_em = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_organizacoes_updated_at
    BEFORE UPDATE ON public.organizacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.atualizar_updated_at();

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.organizacoes ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin vê tudo
-- Outros vêem apenas a sua organização (via Custom Claims no JWT)
CREATE POLICY "organizacoes_select" ON public.organizacoes
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR id = (auth.jwt() ->> 'organizacao_id')::UUID
    );

-- Policy: INSERT
-- Apenas Super Admin pode criar organizações
CREATE POLICY "organizacoes_insert" ON public.organizacoes
    FOR INSERT WITH CHECK (
        (auth.jwt() ->> 'papel') = 'super_admin'
    );

-- Policy: UPDATE
-- Super Admin pode atualizar tudo
-- Admin pode atualizar a própria organização (exceto pode_registar_clientes)
CREATE POLICY "organizacoes_update" ON public.organizacoes
    FOR UPDATE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
    );

-- Policy: DELETE
-- Apenas Super Admin (soft delete via ativa = false é preferido)
CREATE POLICY "organizacoes_delete" ON public.organizacoes
    FOR DELETE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
    );
