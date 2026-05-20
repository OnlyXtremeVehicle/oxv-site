-- ============================================================
-- OXV — V7.7 Table contact_messages
-- ============================================================
-- Stocke les messages depuis le formulaire de contact public
-- ============================================================

CREATE TABLE IF NOT EXISTS public.contact_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  subject TEXT,
  message TEXT NOT NULL,
  source TEXT DEFAULT 'contact_form',  -- 'contact_form', 'corporate_form', etc.
  status TEXT DEFAULT 'new' CHECK (status IN ('new', 'read', 'replied', 'spam', 'archived')),
  read_at TIMESTAMPTZ,
  read_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  replied_at TIMESTAMPTZ,
  user_agent TEXT,
  ip_address INET,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contact_messages_status ON public.contact_messages(status);
CREATE INDEX IF NOT EXISTS idx_contact_messages_created_at ON public.contact_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contact_messages_email ON public.contact_messages(email);

-- RLS : admin seul lit/modifie, mais public peut INSERT
ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;

-- Tout le monde peut envoyer un message (INSERT)
DROP POLICY IF EXISTS "contact_messages_insert_public" ON public.contact_messages;
CREATE POLICY "contact_messages_insert_public" ON public.contact_messages
  FOR INSERT WITH CHECK (true);

-- Seul l'admin lit/modifie/supprime
DROP POLICY IF EXISTS "contact_messages_admin_all" ON public.contact_messages;
CREATE POLICY "contact_messages_admin_all" ON public.contact_messages
  FOR ALL USING (is_admin());

-- Vérification
SELECT 
  'contact_messages' AS table_name, 
  (SELECT COUNT(*) FROM public.contact_messages) AS row_count;
