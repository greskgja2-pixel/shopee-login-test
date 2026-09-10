# Teste de login Shopee

App bem simples em Next.js com uma única função: testar o fluxo de
autorização (login) de uma loja Shopee via Shopee Open Platform, usando o
Partner ID e o Partner Key do seu app.

## Como funciona

1. A página inicial (`/`) mostra um botão **"Conectar loja Shopee"**.
2. Ao clicar, `/api/shopee/authorize` monta a URL de autorização (assinada
   com HMAC-SHA256 usando o Partner Key) e redireciona para a Shopee.
3. Você faz login e autoriza a loja no site da Shopee.
4. A Shopee redireciona de volta para `/api/shopee/callback`, que troca o
   `code` recebido por um `access_token`/`refresh_token`.
5. Você é redirecionado para `/connected`, que mostra o resultado (tokens
   mascarados, só para conferir que o login funcionou).

Não há banco de dados nem persistência — é só para validar que o login
está funcionando antes de virar parte de um app maior.

## 1. Criar o app no Shopee Open Platform

No [Open Platform da Shopee](https://open.shopee.com/) (ou no ambiente de
testes, se você tiver acesso ao sandbox), crie/edite seu app e anote:

- **Partner ID**
- **Partner Key**

E cadastre a URL de callback do seu app, que vai ser:

```
https://SEU-APP.vercel.app/api/shopee/callback
```

## 2. Colocar o código no GitHub

Suba esta pasta como um repositório novo no GitHub (do jeito que você já
faz com os outros projetos).

## 3. Deploy na Vercel

1. Importe o repositório na Vercel.
2. Em **Project Settings > Environment Variables**, adicione:

   | Nome | Valor |
   |---|---|
   | `SHOPEE_PARTNER_ID` | seu Partner ID |
   | `SHOPEE_PARTNER_KEY` | seu Partner Key |
   | `SHOPEE_REDIRECT_URL` | `https://SEU-APP.vercel.app/api/shopee/callback` (a mesma URL cadastrada no passo 1) |
   | `SHOPEE_ENV` | `test` para sandbox, `live` para produção |

3. Faça o deploy (ou redeploy, se já tiver feito o deploy antes de
   configurar as variáveis).

## 4. Testar

Acesse `https://SEU-APP.vercel.app/`, clique em **Conectar loja Shopee** e
siga o fluxo. Se tudo estiver certo, você cai em `/connected` vendo o
`shop_id` e os tokens (mascarados).

## Rodando localmente (opcional)

```bash
npm install
cp .env.example .env.local   # preencha as variáveis
npm run dev
```

## Estrutura

```
pages/
  index.js               → botão de login
  connected.js            → tela de resultado
  api/shopee/
    authorize.js           → monta a URL e redireciona pra Shopee
    callback.js             → troca o code pelo access_token
lib/
  shopee.js                 → assinatura HMAC e URL base (test/live)
```
