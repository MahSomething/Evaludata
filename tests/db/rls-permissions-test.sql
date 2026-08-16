-- ============================================================
-- QA-003 (Parte Automatizada): Testes RLS e Permissoes
-- Executar no SQL Editor do Supabase com role 'anon' e 'authenticated'
-- Requer: extensao pgtap (se disponivel) ou execucao manual
-- Data: 2026-08-16
-- ============================================================

-- NOTA: Estes testes simulam diferentes roles usando SET ROLE.
-- Em Supabase, use a funcao auth.uid() e auth.jwt() com mocks
-- ou execute via aplicacao com diferentes utilizadores.

-- --------------------------------------------------------------
-- SETUP: Criar dados de teste
-- --------------------------------------------------------------

-- Organizacao de teste
INSERT INTO organizacoes (id, nome, nuit, pode_registar_clientes, ativa)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Org Teste QA',
  '111111111',
  true,
  true
)
ON CONFLICT (id) DO NOTHING;

-- Utilizadores de teste (usando auth.users diretamente — service role)
-- Nota: Em producao, use a API de Auth. Aqui e para teste SQL.

-- Admin
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'admin.qa@teste.com',
  '{"organizacao_id": "11111111-1111-1111-1111-111111111111", "papel": "admin", "nome": "Admin QA"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO utilizadores (id, organizacao_id, email, nome, papel, ativo)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  'admin.qa@teste.com',
  'Admin QA',
  'admin',
  true
)
ON CONFLICT (id) DO NOTHING;

-- Contabilista
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'cont.qa@teste.com',
  '{"organizacao_id": "11111111-1111-1111-1111-111111111111", "papel": "contabilista", "nome": "Cont QA"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO utilizadores (id, organizacao_id, email, nome, papel, ativo)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '11111111-1111-1111-1111-111111111111',
  'cont.qa@teste.com',
  'Cont QA',
  'contabilista',
  true
)
ON CONFLICT (id) DO NOTHING;

-- Cliente
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'cliente.qa@teste.com',
  '{"organizacao_id": "11111111-1111-1111-1111-111111111111", "papel": "cliente", "nome": "Cliente QA"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO utilizadores (id, organizacao_id, email, nome, papel, telemovel, ativo)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '11111111-1111-1111-1111-111111111111',
  'cliente.qa@teste.com',
  'Cliente QA',
  'cliente',
  '258841234567',
  true
)
ON CONFLICT (id) DO NOTHING;

-- Empresas
INSERT INTO empresas (id, organizacao_id, nome, nuit, ativa)
VALUES
  ('e1111111-e111-e111-e111-e11111111111', '11111111-1111-1111-1111-111111111111', 'Empresa QA 1', '111111111', true),
  ('e2222222-e222-e222-e222-e22222222222', '11111111-1111-1111-1111-111111111111', 'Empresa QA 2', '222222222', true)
ON CONFLICT (id) DO NOTHING;

-- Atribuir Contabilista A a Empresa 1
INSERT INTO contabilista_empresas (contabilista_id, empresa_id, atribuido_por)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'e1111111-e111-e111-e111-e11111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
ON CONFLICT (contabilista_id, empresa_id) DO NOTHING;

-- Atribuir Cliente a Empresa 1
INSERT INTO cliente_empresas (cliente_id, empresa_id, atribuido_por)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'e1111111-e111-e111-e111-e11111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
ON CONFLICT (cliente_id, empresa_id) DO NOTHING;

-- Documentos
INSERT INTO documentos (id, organizacao_id, empresa_id, ficheiro_nome, tipo_documento, estado, ano)
VALUES
  ('d1111111-d111-d111-d111-d11111111111', '11111111-1111-1111-1111-111111111111', 'e1111111-e111-e111-e111-e11111111111', 'doc1.pdf', 'Comparativo IVA', 'ativo', 2026),
  ('d2222222-d222-d222-d222-d22222222222', '11111111-1111-1111-1111-111111111111', 'e1111111-e111-e111-e111-e11111111111', 'doc2.pdf', 'Relatorio IRS', 'pendente', 2026),
  ('d3333333-d333-d333-d333-d33333333333', '11111111-1111-1111-1111-111111111111', 'e2222222-e222-e222-e222-e22222222222', 'doc3.pdf', 'Comparativo IVA', 'ativo', 2026)
ON CONFLICT (id) DO NOTHING;

-- --------------------------------------------------------------
-- TESTE 1: Anonimo nao ve nada
-- --------------------------------------------------------------
DO $$
DECLARE
  cnt INT;
BEGIN
  -- Simular anonimo (sem JWT)
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '', true);
  PERFORM set_config('request.jwt.claim.papel', '', true);

  SELECT COUNT(*) INTO cnt FROM empresas;
  IF cnt > 0 THEN
    RAISE EXCEPTION 'FALHA: Anonimo consegue ver % empresas', cnt;
  ELSE
    RAISE NOTICE '[OK] Teste 1: Anonimo nao ve empresas.';
  END IF;
END $$;

-- --------------------------------------------------------------
-- TESTE 2: Admin ve todas as empresas da sua org
-- --------------------------------------------------------------
DO $$
DECLARE
  cnt INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '11111111-1111-1111-1111-111111111111', true);
  PERFORM set_config('request.jwt.claim.papel', 'admin', true);

  SELECT COUNT(*) INTO cnt FROM empresas;
  IF cnt != 2 THEN
    RAISE EXCEPTION 'FALHA: Admin ve % empresas (esperado 2)', cnt;
  ELSE
    RAISE NOTICE '[OK] Teste 2: Admin ve 2 empresas.';
  END IF;
END $$;

-- --------------------------------------------------------------
-- TESTE 3: Contabilista so ve empresas atribuidas
-- --------------------------------------------------------------
DO $$
DECLARE
  cnt INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '11111111-1111-1111-1111-111111111111', true);
  PERFORM set_config('request.jwt.claim.papel', 'contabilista', true);

  SELECT COUNT(*) INTO cnt FROM empresas;
  IF cnt != 1 THEN
    RAISE EXCEPTION 'FALHA: Contabilista ve % empresas (esperado 1)', cnt;
  ELSE
    RAISE NOTICE '[OK] Teste 3: Contabilista ve 1 empresa (atribuida).';
  END IF;
END $$;

-- --------------------------------------------------------------
-- TESTE 4: Cliente so ve empresas atribuidas
-- --------------------------------------------------------------
DO $$
DECLARE
  cnt INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '11111111-1111-1111-1111-111111111111', true);
  PERFORM set_config('request.jwt.claim.papel', 'cliente', true);

  SELECT COUNT(*) INTO cnt FROM empresas;
  IF cnt != 1 THEN
    RAISE EXCEPTION 'FALHA: Cliente ve % empresas (esperado 1)', cnt;
  ELSE
    RAISE NOTICE '[OK] Teste 4: Cliente ve 1 empresa (atribuida).';
  END IF;
END $$;

-- --------------------------------------------------------------
-- TESTE 5: Cliente so ve documentos 'ativo'
-- --------------------------------------------------------------
DO $$
DECLARE
  cnt INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '11111111-1111-1111-1111-111111111111', true);
  PERFORM set_config('request.jwt.claim.papel', 'cliente', true);

  SELECT COUNT(*) INTO cnt FROM documentos;
  IF cnt != 1 THEN
    RAISE EXCEPTION 'FALHA: Cliente ve % documentos (esperado 1 ativo)', cnt;
  ELSE
    RAISE NOTICE '[OK] Teste 5: Cliente ve 1 documento (ativo).';
  END IF;
END $$;

-- --------------------------------------------------------------
-- TESTE 6: Contabilista ve documentos (todos exceto eliminado)
-- --------------------------------------------------------------
DO $$
DECLARE
  cnt INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '11111111-1111-1111-1111-111111111111', true);
  PERFORM set_config('request.jwt.claim.papel', 'contabilista', true);

  SELECT COUNT(*) INTO cnt FROM documentos;
  IF cnt != 2 THEN
    RAISE EXCEPTION 'FALHA: Contabilista ve % documentos (esperado 2: ativo+pendente)', cnt;
  ELSE
    RAISE NOTICE '[OK] Teste 6: Contabilista ve 2 documentos.';
  END IF;
END $$;

-- --------------------------------------------------------------
-- TESTE 7: log_acessos nao permite UPDATE
-- --------------------------------------------------------------
DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '11111111-1111-1111-1111-111111111111', true);
  PERFORM set_config('request.jwt.claim.papel', 'admin', true);

  BEGIN
    UPDATE log_acessos SET acao = 'hackeado' WHERE TRUE;
    RAISE EXCEPTION 'FALHA: Admin conseguiu UPDATE em log_acessos';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE '[OK] Teste 7: log_acessos e imutavel (UPDATE bloqueado).';
  END;
END $$;

-- --------------------------------------------------------------
-- TESTE 8: log_acessos nao permite DELETE
-- --------------------------------------------------------------
DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  PERFORM set_config('request.jwt.claim.organizacao_id', '11111111-1111-1111-1111-111111111111', true);
  PERFORM set_config('request.jwt.claim.papel', 'admin', true);

  BEGIN
    DELETE FROM log_acessos WHERE TRUE;
    RAISE EXCEPTION 'FALHA: Admin conseguiu DELETE em log_acessos';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE '[OK] Teste 8: log_acessos e imutavel (DELETE bloqueado).';
  END;
END $$;

-- --------------------------------------------------------------
-- LIMPEZA: Remover dados de teste (opcional — comentar se quiser manter)
-- --------------------------------------------------------------
-- DELETE FROM documentos WHERE id LIKE 'd%';
-- DELETE FROM cliente_empresas WHERE cliente_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
-- DELETE FROM contabilista_empresas WHERE contabilista_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
-- DELETE FROM empresas WHERE id LIKE 'e%';
-- DELETE FROM utilizadores WHERE id IN ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc');
-- DELETE FROM auth.users WHERE id IN ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc');
-- DELETE FROM organizacoes WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT 'TESTES RLS CONCLUIDOS COM SUCESSO' AS resultado;
