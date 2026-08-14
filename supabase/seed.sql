-- Seed: Dados iniciais do sistema
-- Tarefa: DB-012
--
-- NOTA: Este ficheiro é executado automaticamente por:
--   supabase db reset
--   supabase start (primeira vez)
--
-- Para gerar a password hash do Super Admin:
--   node -e "const bcrypt = require('bcrypt'); console.log(bcrypt.hashSync('SuperAdmin123!', 10));"
--
-- IMPORTANTE: O Super Admin deve ser criado MANUALMENTE no Supabase Dashboard
-- pois a tabela auth.users é gerida pelo Supabase Auth e não pode ser manipulada
-- diretamente via seed em todos os ambientes.
--
-- Alternativa: Criar o utilizador via Supabase Auth API e depois inserir na tabela public.utilizadores.

-- ============================================
-- TIPOS DE DOCUMENTO PADRÃO
-- ============================================

INSERT INTO public.tipos_documento (nome, descricao) VALUES
    ('Comparativo IVA', 'Comparativo mensal/trimestral de IVA'),
    ('Relatório IRS', 'Relatório de entrega do IRS'),
    ('Extrato Bancário', 'Extrato bancário mensal'),
    ('Declaração IES', 'Declaração anual de IES'),
    ('Recibo Verde', 'Recibo de trabalhador independente'),
    ('Fatura', 'Fatura de despesa/receita'),
    ('Outro', 'Documento não categorizado')
ON CONFLICT (nome) DO NOTHING;

-- ============================================
-- NOTA SOBRE SUPER ADMIN
-- ============================================
--
-- O Super Admin deve ser criado em 2 passos:
--
-- PASSO 1: Criar via Supabase Auth API (ou Dashboard)
--   Email: superadmin@evaludata.pt
--   Password: (definir no momento da criação)
--
-- PASSO 2: Inserir na tabela public.utilizadores com o UUID retornado
--
-- Exemplo (executar APÓS criar o user no Auth):
--
-- INSERT INTO public.utilizadores (id, email, nome, papel, ativo, organizacao_id)
-- VALUES (
--     'UUID-DO-AUTH-USER-AQUI',
--     'superadmin@evaludata.pt',
--     'Super Admin',
--     'super_admin',
--     true,
--     NULL
-- );
--
-- PASSO 3: Atualizar app_metadata do user no Auth para incluir claims
--   organizacao_id: null
--   papel: super_admin
--
-- Isto pode ser feito via Dashboard → Auth → Users → [user] → Edit → App Metadata
-- Ou via API: supabase.auth.admin.updateUserById()
