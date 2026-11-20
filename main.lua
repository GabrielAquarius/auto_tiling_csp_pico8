-- ==========================================
-- 1. CATALOGO DE RECORTES: {sx, sy, sw, sh, ox, oy, camada}
-- ox e oy sao os deslocamentos dentro do tile 8x8
-- camada: 1=bordas, 2=quinas internas, 3=quinas externas
-- ==========================================
pecas = {
  -- bordas retas (camada 1)
  top_edge    = {8, 0, 8, 5, 0, 0, 1},
  bottom_edge = {8, 6, 8, 2, 0, 6, 1}, -- oy=6 (desce p/ base do tile)
  left_edge   = {16, 0, 3, 8, 0, 0, 1},
  right_edge  = {20, 0, 4, 8, 4, 0, 1}, -- ox=4 (encosta na direita: 8-4=4)

  -- quinas internas (camada 2 - continuidade nas diagonais abertas)
  tl_in = {24, 0, 1, 2, 0, 0, 2},
  tr_in = {31, 0, 1, 2, 7, 0, 2}, -- ox=7 (canto direito)
  bl_in = {24, 7, 1, 1, 0, 7, 2}, -- oy=7 (canto inferior)
  br_in = {30, 7, 2, 1, 6, 7, 2}, -- ox=6, oy=7

  -- quinas externas (camada 3 - encerramento por cima das bordas)
  tl_out = {32, 0, 3, 5, 0, 0, 3},
  tr_out = {37, 0, 3, 5, 5, 0, 3}, -- ox=5 (8-3=5)
  bl_out = {32, 6, 3, 2, 0, 6, 3},
  br_out = {37, 6, 3, 2, 5, 6, 3}
}

-- matriz padrao de demonstracao (12x8)
-- 1 = terra, 0 = ar
mapa_padrao = {
  {0,0,0,0,0,0,0,0,0,0,0,0},
  {0,1,0,0,1,1,1,1,1,0,0,0},
  {0,0,0,0,1,1,1,1,1,0,0,0},
  {0,1,1,0,0,0,1,0,0,0,1,0},
  {0,1,1,1,1,1,1,1,0,0,1,0},
  {0,1,1,1,1,1,1,1,0,0,1,0},
  {0,0,1,1,1,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0}
}

mapa = {}

-- tabela que guardara a solucao do csp para o _draw
cache_grama = {}

-- telemetria e contadores do solver
metricas = {
  blocos = 0,
  recortes = 0,
  regras = 0,
  solve_cpu = 0,
  solve_count = 0
}

function copiar_mapa_padrao()
  mapa = {}
  for y = 1, #mapa_padrao do
    local linha = {}
    for x = 1, #mapa_padrao[y] do
      linha[x] = mapa_padrao[y][x]
    end
    mapa[y] = linha
  end
end

function limpar_mapa()
  for y = 1, #mapa do
    for x = 1, #mapa[y] do
      mapa[y][x] = 0
    end
  end
end

function _init()
  poke(0x5f2d, 1) -- habilita mouse e leitura de teclas
  copiar_mapa_padrao()
  resolver_csp()
  init_demo()
end

function _update()
  atualizar_demo()
end

function _draw()
  desenhar_demo()
end
