# Issues e limitações

Nenhuma issue de produto constatada porque a bateria não começou. Prioridades P0–P3 não foram atribuídas ao bloqueio de ambiente.

## TEST_LIMITATION — QA_DOCKER_ENGINE_UNAVAILABLE

Status: open. Personas: CJ-001–CJ-015. Tasks: todas as planejadas.
Esperado: Docker com MySQL 8.4 local isolado disponível.
Observado: engine desktop-linux inacessível; named pipe ausente.
Evidência e reprodução: executar docker version; consultar preflight_evidence.txt.
Impacto: baseline e cenários não iniciados.
Próximo passo: disponibilizar Docker Desktop Linux engine e repetir o preflight antes de executar o plano.
Não usar banco público como workaround. Nenhuma correção de produto realizada.
