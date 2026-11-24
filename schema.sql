-- Floresça: rode este arquivo no Supabase (SQL Editor > New query > Run)

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  nome text not null,
  papel text not null default 'aluno' check (papel in ('aluno','psicologa'))
);
create table availability (
  dia date primary key,
  status text not null check (status in ('ok','no')),
  horas text[] not null default '{}'
);
create table phrases (
  id bigint generated always as identity primary key,
  texto text not null
);

alter table profiles enable row level security;
alter table availability enable row level security;
alter table phrases enable row level security;

-- Verifica se quem está logado é a psicóloga
create function is_psicologa() returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from profiles where id = auth.uid() and papel = 'psicologa')
$$;

-- Cria o perfil (sempre como aluno) quando alguém se cadastra
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- OPCIONAL: aceitar só e-mails da escola (troque o domínio e remova os --)
  -- if new.email not like '%@suaescola.edu.br' then raise exception 'Use o e-mail institucional'; end if;
  insert into profiles (id, nome) values (new.id, coalesce(new.raw_user_meta_data->>'nome', 'Aluno'));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Regras de acesso. Ninguém consegue mudar o próprio papel (não há política de update em profiles).
create policy "ver o próprio perfil" on profiles for select using (id = auth.uid());
create policy "logados veem agenda" on availability for select to authenticated using (true);
create policy "psicóloga altera agenda" on availability for all to authenticated
  using (is_psicologa()) with check (is_psicologa());
create policy "todos veem frases" on phrases for select using (true);
create policy "psicóloga altera frases" on phrases for all to authenticated
  using (is_psicologa()) with check (is_psicologa());

insert into phrases (texto) values
 ('Você é importante, mesmo nos dias em que não consegue enxergar isso.'),
 ('Respeite seu tempo. Cada pessoa tem seu próprio processo.'),
 ('Não há problema em pedir ajuda.'),
 ('Pequenos passos também são progresso.'),
 ('Você não precisa ser forte o tempo todo.'),
 ('Sua saúde emocional também merece atenção.'),
 ('Recomeçar quantas vezes forem necessárias também é coragem.');

-- Depois que a psicóloga criar a conta pelo site, torne-a administradora:
-- update profiles set papel = 'psicologa'
--   where id = (select id from auth.users where email = 'email-da-psicologa@escola.com');
