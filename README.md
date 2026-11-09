# etl-tup

Cópia integral do schema `TUP` (Tabela Unificada de Procedimentos) do Oracle RJPO1DR para o
schema `tup` do PostgreSQL `dbcontroleavaliacao`, no servidor 10.60.67.173. Segue o padrão
dos repositórios `etl-cnes` e `etl-dbgeral`.

O app SUS360 C&A lê a view `tup.vw_procedimento` (descrição dos procedimentos no módulo Alvos).
Essa view depende de `tb_procedimento`, `tb_grupo`, `tb_sub_grupo`, `tb_forma_organizacao` e
`th_procedimento`, todas copiadas aqui.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `run_tup.sh` | Wrapper chamado pelo cron: roda o job num container `pentaho-etl:9.4` e grava o log em `logs/` |
| `tup.kjb` | Job `tup`: as 9 cópias; registra cada execução em `ctl.tb_log_table` e manda e-mail se uma falhar |
| `replicacao_<tabela>.ktr` | `SELECT * FROM TUP.<TABELA>` → apaga `tup.<tabela>` e recarrega inteira |
| `descobrir_colunas_oracle.ktr` | Diagnóstico: lista as colunas do schema TUP que o usuário consegue ler |

Tabelas, na ordem do job: `tb_grupo`, `tb_sub_grupo`, `tb_forma_organizacao`, `tb_procedimento`,
`th_procedimento`, `tb_detalhe`, `rl_procedimento_detalhe`, `tb_regra_condicionada`,
`rl_procedimento_regra_cond`.

Credenciais: `/home/ec2-user/.kettle/kettle.properties` (`DBCA_*`, `RJPO1DR_TNS`, `RJPO1DR_SIA_USER`,
`RJPO1DR_SIA_PASSWORD`): o usuário SUS360, o mesmo do SIA e do SIH, que tem leitura no schema TUP.

## Deploy no servidor (10.60.67.173)

1. Clonar (o atalho `github-etl-tup` já está no `~/.ssh/config`; a chave pública
   `~/.ssh/deploy_etl_tup.pub` precisa estar nas Deploy keys do repositório, só leitura):
   ```bash
   ssh -T github-etl-tup
   cd /opt/pentaho-etl/projetos
   git clone github-etl-tup:adeilsonjunior/etl-tup.git tup
   ls -l tup/run_tup.sh   # deve vir com x
   ```
2. Diagnóstico: confere o acesso ao schema TUP (deve listar as tabelas e colunas):
   ```bash
   docker run --rm --network host \
     -v /home/ec2-user/.kettle/kettle.properties:/home/pentaho/.kettle/kettle.properties:ro \
     -v /opt/pentaho-etl/projetos/tup:/opt/pentaho/projetos/tup -v /tmp:/tmp \
     --entrypoint /opt/pentaho/data-integration/pan.sh pentaho-etl:9.4 \
     -file=/opt/pentaho/projetos/tup/descobrir_colunas_oracle.ktr \
     -param:OUTPUT_FILE=/tmp/colunas_tup.txt -level=Basic > /tmp/colunas_tup.log 2>&1; echo "exit=$?"
   cut -d';' -f1 /tmp/colunas_tup.txt | sort | uniq -c
   ```
3. Primeira execução manual (apaga e recarrega as 9 tabelas; menos de um minuto):
   ```bash
   ./tup/run_tup.sh; echo "exit=$?"
   ```
4. Agendar no cron (`crontab -e`). O servidor está em UTC: 04:30 UTC = 01:30 de Brasília,
   depois do CNES (04:00 UTC):
   ```
   30 4 * * * /opt/pentaho-etl/projetos/tup/run_tup.sh
   ```

## Atualizar

```bash
cd /opt/pentaho-etl/projetos/tup && git pull --ff-only
```

Nunca editar arquivos direto no servidor: toda mudança passa pelo repositório.
