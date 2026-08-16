-- Migration: 006_documentos
-- Criacao da tabela de documentos com versionamento e aprovacao
-- Tarefa: DB-005
-- CORRECAO: Subqueries em policies RLS removidas — funcoes SECURITY DEFINER

-- ============================================
-- TIPO ENUM: estado_documento
-- ============================================

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_documento_enum') THEN
 CREATE TYPE public.estado_documento_enum AS ENUM (
 'ativo',
 'pendente',
 'rejeitado',
 'arquivado',
 'eliminado'
 );
 END IF;
END $$;

-- ============================================
-- FUNCOES DE SEGURANCA (SECURITY DEFINER)
-- Substituem subqueries em policies RLS
-- ============================================

CREATE OR REPLACE FUNCTION public.is_contabilista_empresa(p_empresa_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.contabilista_empresas
    WHERE contabilista_id = auth.uid()
    AND empresa_id = p_empresa_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_cliente_empresa(p_empresa_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.cliente_empresas
    WHERE cliente_id = auth.uid()
    AND empresa_id = p_empresa_id
  );
$$;

-- ============================================
-- TABELA: documentos
-- ============================================

CREATE TABLE IF NOT EXISTS public.documentos (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 empresa_id UUID NOT NULL,
 organizacao_id UUID NOT NULL,
 tipo_documento TEXT NOT NULL,
 ano INTEGER NOT NULL CHECK (ano >= 2000 AND ano <= 2100),
 periodo TEXT,
 ficheiro_url TEXT NOT NULL,
 ficheiro_nome TEXT NOT NULL,
 ficheiro_tamanho INTEGER NOT NULL CHECK (ficheiro_tamanho > 0),

 versao INTEGER NOT NULL DEFAULT 1,
 documento_pai_id UUID,
 estado public.estado_documento_enum NOT NULL DEFAULT 'ativo',
 substitui_id UUID,

 data_soft_delete TIMESTAMPTZ,

 metadados JSONB DEFAULT '{}',
 notas TEXT,

 criado_por UUID NOT NULL,
 criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 atualizado_por UUID,
 atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

 CONSTRAINT fk_documentos_empresa
 FOREIGN KEY (empresa_id)
 REFERENCES public.empresas(id)
 ON DELETE CASCADE,

 CONSTRAINT fk_documentos_organizacao
 FOREIGN KEY (organizacao_id)
 REFERENCES public.organizacoes(id)
 ON DELETE CASCADE,

 CONSTRAINT fk_documentos_documento_pai
 FOREIGN KEY (documento_pai_id)
 REFERENCES public.documentos(id)
 ON DELETE SET NULL,

 CONSTRAINT fk_documentos_substitui
 FOREIGN KEY (substitui_id)
 REFERENCES public.documentos(id)
 ON DELETE SET NULL,

 CONSTRAINT fk_documentos_criado_por
 FOREIGN KEY (criado_por)
 REFERENCES public.utilizadores(id)
 ON DELETE SET NULL,

 CONSTRAINT fk_documentos_atualizado_por
 FOREIGN KEY (atualizado_por)
 REFERENCES public.utilizadores(id)
 ON DELETE SET NULL
);

COMMENT ON TABLE public.documentos IS 'Documentos fiscais e contabilisticos das empresas';
COMMENT ON COLUMN public.documentos.periodo IS 'Periodo do documento: mes, trimestre, ou outro identificador';
COMMENT ON COLUMN public.documentos.documento_pai_id IS 'Se este documento e uma revisao de outro, aponta para o original';
COMMENT ON COLUMN public.documentos.substitui_id IS 'Se este documento substitui outro, aponta para o documento substituido';
COMMENT ON COLUMN public.documentos.data_soft_delete IS 'Data em que o documento foi marcado como eliminado ou rejeitado (90 dias ate remocao fisica)';
COMMENT ON COLUMN public.documentos.metadados IS 'Campos flexiveis em JSON para extensibilidade futura';

-- ============================================
-- INDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_documentos_empresa ON public.documentos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_documentos_organizacao ON public.documentos(organizacao_id);
CREATE INDEX IF NOT EXISTS idx_documentos_estado ON public.documentos(estado);
CREATE INDEX IF NOT EXISTS idx_documentos_ano ON public.documentos(ano);
CREATE INDEX IF NOT EXISTS idx_documentos_tipo ON public.documentos(tipo_documento);
CREATE INDEX IF NOT EXISTS idx_documentos_empresa_estado_ano ON public.documentos(empresa_id, estado, ano DESC);
CREATE INDEX IF NOT EXISTS idx_documentos_soft_delete ON public.documentos(data_soft_delete)
 WHERE data_soft_delete IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_documentos_fts ON public.documentos
 USING gin (to_tsvector('portuguese',
 COALESCE(ficheiro_nome, '') || ' ' ||
 COALESCE(tipo_documento, '') || ' ' ||
 COALESCE(notas, '')
 ));

-- ============================================
-- TRIGGER: atualizar updated_at
-- ============================================

CREATE TRIGGER trg_documentos_updated_at
 BEFORE UPDATE ON public.documentos
 FOR EACH ROW
 EXECUTE FUNCTION public.atualizar_updated_at();

-- ============================================
-- RLS: Row Level Security (SEM SUBQUERIES)
-- ============================================

ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin ve tudo
-- Admin ve tudo da sua org
-- Contabilista ve documentos das empresas atribuidas (via funcao)
-- Cliente ve apenas documentos 'ativo' das empresas atribuidas (via funcao)
CREATE POLICY "documentos_select" ON public.documentos
 FOR SELECT USING (
 (auth.jwt() ->> 'papel') = 'super_admin'
 OR (
 organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
 AND (auth.jwt() ->> 'papel') = 'admin'
 )
 OR (
 (auth.jwt() ->> 'papel') = 'contabilista'
 AND public.is_contabilista_empresa(empresa_id)
 )
 OR (
 estado = 'ativo'
 AND (auth.jwt() ->> 'papel') = 'cliente'
 AND public.is_cliente_empresa(empresa_id)
 )
 );

-- Policy: INSERT
-- Super Admin, Admin da org, ou Contabilista das empresas atribuidas (via funcao)
CREATE POLICY "documentos_insert" ON public.documentos
 FOR INSERT WITH CHECK (
 (auth.jwt() ->> 'papel') = 'super_admin'
 OR (
 organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
 AND (auth.jwt() ->> 'papel') = 'admin'
 )
 OR (
 (auth.jwt() ->> 'papel') = 'contabilista'
 AND public.is_contabilista_empresa(empresa_id)
 )
 );

-- Policy: UPDATE
-- Super Admin pode tudo
-- Admin pode atualizar tudo da sua org
-- Contabilista pode editar metadados dos seus proprios documentos
CREATE POLICY "documentos_update" ON public.documentos
 FOR UPDATE USING (
 (auth.jwt() ->> 'papel') = 'super_admin'
 OR (
 organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
 AND (auth.jwt() ->> 'papel') = 'admin'
 )
 OR (
 criado_por = (auth.jwt() ->> 'sub')::UUID
 AND (auth.jwt() ->> 'papel') = 'contabilista'
 AND estado IN ('ativo', 'pendente', 'rejeitado', 'arquivado')
 )
 );

-- Policy: DELETE
-- Apenas Super Admin
CREATE POLICY "documentos_delete" ON public.documentos
 FOR DELETE USING (
 (auth.jwt() ->> 'papel') = 'super_admin'
 );
