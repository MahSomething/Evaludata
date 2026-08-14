-- Migration: 010_tipos_documento
-- Tabela de tipos de documento configuráveis
-- Tarefa: DB-012 (Parte 1/2)

-- ============================================
-- TABELA: tipos_documento
-- ============================================

CREATE TABLE IF NOT EXISTS public.tipos_documento (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT UNIQUE NOT NULL,
    descricao TEXT,
    ativo BOOLEAN NOT NULL DEFAULT true,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Comentários
COMMENT ON TABLE public.tipos_documento IS 'Lista configurável de tipos de documentos fiscais/contabilísticos';

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_tipos_documento_ativo ON public.tipos_documento(ativo);

-- ============================================
-- RLS
-- ============================================

ALTER TABLE public.tipos_documento ENABLE ROW LEVEL SECURITY;

-- Todos os utilizadores autenticados podem ver tipos ativos
CREATE POLICY "tipos_documento_select" ON public.tipos_documento
    FOR SELECT USING (ativo = true);

-- Apenas Super Admin pode gerir tipos
CREATE POLICY "tipos_documento_write" ON public.tipos_documento
    FOR ALL USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
    );
