-- ==========================================
-- INTERFACE DE APRESENTACAO (3 TELAS)
-- 1: rom vs csp | 2: passo a passo | 3: live + telemetria
-- ==========================================

demo = {
  tela = 1,          -- 1, 2 ou 3
  -- mouse
  mx = 0,
  my = 0,
  mb_esq = false,
  mb_esq_ant = false,
  mb_dir = false,
  clicou_esq = false,
  -- tela 1: filtro de camadas (0=base, 1=+c1, 2=+c2, 3=todas)
  camada_max = 3,
  -- tela 2: passo a passo do solver
  passo = 0,
  tocando = false,
  timer_play = 0,
  delay_play = 10,   -- frames por passo no modo play
  -- tela 3: sandbox interativo + telemetria
  cx = 1,            -- cursor de grade (1..12)
  cy = 1,            -- cursor de grade (1..8)
  pintando = nil,    -- 0 ou 1 durante arraste do mouse
  cpu_suave = 0
}

-- nomes das camadas para a tela 1
nomes_camada = {
  [0] = "base",
  [1] = "c1",
  [2] = "c1+c2",
  [3] = "todas"
}

-- offsets dos 8 vizinhos (na ordem de celula.viz)
viz_offsets = {
  {-1, -1}, {0, -1}, {1, -1},
  {-1,  0}, {0,  0}, {1,  0},
  {-1,  1}, {0,  1}, {1,  1}
}

function init_demo()
  demo.tela = 1
  demo.camada_max = 3
  demo.passo = 0
  demo.tocando = false
  demo.cx = 2
  demo.cy = 2
end

-- formata float com 1 casa decimal sem estouro 16.16
function fmt1(v)
  if (v < 0) v = 0
  local n = flr(v * 10 + 0.5)
  local ip = flr(n / 10)
  local dp = n % 10
  return ip.."."..dp
end

function mudar_tela(nova)
  demo.tela = nova
  demo.pintando = nil
  if nova == 2 then
    -- garante que o passo esta dentro do tamanho atual do mapa
    if demo.passo > #cache_grama then
      demo.passo = #cache_grama
    end
  end
end

-- desenha um unico bloco (terra + recortes ate camada_max)
function desenhar_bloco(celula, ox, oy, camada_max)
  local dx = ox + celula.x * 8
  local dy = oy + celula.y * 8
  spr(0, dx, dy)
  if camada_max > 0 then
    for rec in all(celula.recortes) do
      if rec[7] <= camada_max then
        sspr(rec[1], rec[2], rec[3], rec[4], dx + rec[5], dy + rec[6])
      end
    end
  end
end

-- desenha o mapa completo a partir do cache
function desenhar_mapa_cache(ox, oy, camada_max, limite_passo)
  local mw = #mapa[1] * 8
  local mh = #mapa * 8
  rectfill(ox - 1, oy - 1, ox + mw, oy + mh, 12)
  rect(ox - 1, oy - 1, ox + mw, oy + mh, 13)

  for i = 1, #cache_grama do
    local cel = cache_grama[i]
    if limite_passo == nil or i <= limite_passo then
      desenhar_bloco(cel, ox, oy, camada_max)
    else
      -- celulas ainda nao resolvidas ficam como terra bruta
      spr(0, ox + cel.x * 8, oy + cel.y * 8)
    end
  end
end

-- ==========================================
-- UPDATE PRINCIPAL
-- ==========================================
function atualizar_demo()
  -- atualiza estado do mouse
  demo.mx = stat(32)
  demo.my = stat(33)
  demo.mb_esq_ant = demo.mb_esq
  demo.mb_esq = band(stat(34), 1) > 0
  demo.mb_dir = band(stat(34), 2) > 0
  demo.clicou_esq = demo.mb_esq and not demo.mb_esq_ant

  -- media movel suave da cpu (para leitura confortavel)
  local cpu_atual = stat(1) * 100
  demo.cpu_suave = demo.cpu_suave * 0.85 + cpu_atual * 0.15

  -- clique na barra de abas superior (y = 0..8)
  if demo.clicou_esq and demo.my <= 8 then
    if demo.mx < 42 then
      mudar_tela(1)
    elseif demo.mx < 85 then
      mudar_tela(2)
    else
      mudar_tela(3)
    end
    return
  end

  -- atalhos de teclado (1, 2, 3, r, c, espaco)
  local tecla_r = false
  local tecla_c = false
  local tecla_esp = false
  while stat(30) do
    local k = stat(31)
    if (k == "1") mudar_tela(1)
    if (k == "2") mudar_tela(2)
    if (k == "3") mudar_tela(3)
    if (k == "r") tecla_r = true
    if (k == "c") tecla_c = true
    if (k == " ") tecla_esp = true
  end

  -- botao x (5) cicla entre as 3 telas em qualquer momento
  if btnp(5) then
    mudar_tela((demo.tela % 3) + 1)
    return
  end

  if demo.tela == 1 then
    atualizar_tela1()
  elseif demo.tela == 2 then
    atualizar_tela2(tecla_r, tecla_esp)
  else
    atualizar_tela3(tecla_r, tecla_c)
  end
end

-- ==========================================
-- TELA 1: SPRITE SHEET VS RESULTADO + ROM
-- ==========================================
function atualizar_tela1()
  -- z alterna visualizacao das camadas (base -> c1 -> c1+c2 -> todas)
  if btnp(4) then
    demo.camada_max = (demo.camada_max + 1) % 4
  end
  -- setas tambem navegam telas na tela 1
  if (btnp(0)) mudar_tela(3)
  if (btnp(1)) mudar_tela(2)
  -- clique na area do mapa tambem alterna camada
  if demo.clicou_esq and demo.my >= 41 and demo.my <= 104 then
    demo.camada_max = (demo.camada_max + 1) % 4
  end
end

function desenhar_tela1()
  print("sprites na rom: 5/256 (160b)", 8, 10, 7)

  -- exibe os 5 sprites reais da sprite sheet em zoom 2x (16x16)
  local labels = {"base", " n/s", " o/l", "q-in", "q-ex"}
  for i = 0, 4 do
    local sx = 9 + i * 23
    rectfill(sx - 1, 16, sx + 16, 33, 0)
    rect(sx - 1, 16, sx + 16, 33, 13)
    sspr(i * 8, 0, 8, 8, sx, 17, 16, 16)
    print(labels[i + 1], sx, 35, 6)
  end

  -- mapa montado pelo csp
  desenhar_mapa_cache(16, 41, demo.camada_max, nil)

  -- painel inferior: comparativo de memoria estatica (rom)
  rectfill(0, 106, 127, 127, 1)
  line(0, 106, 127, 106, 13)

  -- barra manual (47 tiles = 1504 bytes)
  print("mANUAL:47=1504BYTES", 2, 108, 7)
  --rectfill(54, 108, 124, 112, 8)
  rectfill(80, 108, 124, 112, 8)

  -- barra csp (5 sprites = 160 bytes -> 5/47 da largura = ~7px)
  print("sOLVER:05=160BYTES", 2, 114, 7)
  --rectfill(54, 114, 61, 118, 11)
  rectfill(80, 114, 85, 118, 11)
  print("-89.4%", 87, 114, 11)

  -- rodape de controle
  print("z:camada ["..nomes_camada[demo.camada_max].."]", 2, 121, 10)
  print("x:prox>", 96, 121, 6)
end

-- ==========================================
-- TELA 2: PASSO A PASSO DO SOLVER CSP
-- ==========================================
function atualizar_tela2(tecla_r, tecla_esp)
  local total = #cache_grama
  if (total == 0) return

  -- reset passo
  if tecla_r or (demo.clicou_esq and demo.my >= 119 and demo.mx >= 92) then
    demo.passo = 0
    demo.tocando = false
    return
  end

  -- play / pause (z ou espaco ou clique no rodape esquerdo)
  if btnp(4) or tecla_esp or (demo.clicou_esq and demo.my >= 119 and demo.mx < 48) then
    demo.tocando = not demo.tocando
    if demo.tocando and demo.passo >= total then
      demo.passo = 0
    end
  end

  -- passo manual com setas esquerda / direita
  if btnp(0) then
    demo.tocando = false
    demo.passo = max(0, demo.passo - 1)
  elseif btnp(1) then
    demo.tocando = false
    demo.passo = min(total, demo.passo + 1)
  end

  -- velocidade do play com cima / baixo
  if (btnp(2)) demo.delay_play = max(2, demo.delay_play - 3)
  if (btnp(3)) demo.delay_play = min(30, demo.delay_play + 3)

  -- clique direto em uma celula do mapa pula o inspetor para ela
  if demo.clicou_esq and demo.my >= 10 and demo.my <= 73 then
    local gx = flr((demo.mx - 16) / 8)
    local gy = flr((demo.my - 10) / 8)
    for i = 1, total do
      if cache_grama[i].x == gx and cache_grama[i].y == gy then
        demo.passo = i
        demo.tocando = false
        break
      end
    end
  end

  -- avanco automatico no modo play
  if demo.tocando then
    demo.timer_play += 1
    if demo.timer_play >= demo.delay_play then
      demo.timer_play = 0
      if demo.passo < total then
        demo.passo += 1
      else
        demo.tocando = false
      end
    end
  end
end

function desenhar_tela2()
  local ox, oy = 16, 10
  desenhar_mapa_cache(ox, oy, 3, demo.passo)

  -- destaca celula ativa e seus 8 vizinhos no mapa
  local total = #cache_grama
  local cel = nil
  if demo.passo >= 1 and demo.passo <= total then
    cel = cache_grama[demo.passo]
    local cx = ox + cel.x * 8
    local cy = oy + cel.y * 8

    -- destaca os 8 vizinhos (verde=1 terra, vermelho=0 ar)
    for k = 1, 9 do
      if k != 5 then
        local vx = cx + viz_offsets[k][1] * 8
        local vy = cy + viz_offsets[k][2] * 8
        if vx >= ox and vx < ox + 96 and vy >= oy and vy < oy + 64 then
          local cor = cel.viz[k] == 1 and 11 or 8
          rect(vx, vy, vx + 7, vy + 7, cor)
        end
      end
    end

    -- moldura amarela pulsante na celula sob avaliacao
    local cor_foco = (flr(time() * 8) % 2 == 0) and 10 or 7
    rect(cx - 1, cy - 1, cx + 8, cy + 8, cor_foco)
  end

  -- painel inspetor inferior (y = 75..118)
  rectfill(0, 75, 127, 118, 0)
  line(0, 75, 127, 75, 13)

  if total == 0 then
    print("mapa vazio! edite na tela 3", 10, 93, 8)
  elseif cel == nil then
    -- passo 0: antes de rodar o solver
    print("passo 0/"..total.." (matriz bruta)", 6, 82, 10)
    print("terra=1 (blocos sem grama)", 6, 92, 7)
    print("aperte z (play) ou > (passo)", 6, 102, 11)
  else
    -- mini grade 3x3 dos vizinhos a esquerda
    print("viz 3x3", 3, 77, 6)
    for k = 1, 9 do
      if k != 5 then
        local gx = (k - 1) % 3
        local gy = flr((k - 1) / 3)
        local px = 3 + gx * 9
        local py = 84 + gy * 9
        local v = cel.viz[k]
        rectfill(px, py, px + 6, py + 6, v == 1 and 3 or 2)
        print(v, px + 2, py + 1, v == 1 and 11 or 8)
      end
    end
    -- centro mostra o bloco ja montado com moldura amarela
    spr(0, 12, 93)
    for rec in all(cel.recortes) do
      sspr(rec[1], rec[2], rec[3], rec[4], 12 + rec[5], 93 + rec[6])
    end
    rect(11, 92, 20, 101, 10)

    -- regras disparadas por camada a direita
    print("cel("..cel.x..","..cel.y..") "..demo.passo.."/"..total, 34, 77, 7)
    print("c1(bd): "..cel.c1, 34, 85, 11)
    print("c2(in): "..cel.c2, 34, 93, 10)
    print("c3(ex): "..cel.c3, 34, 101, 9)
    print("rec:"..#cel.recortes.."  cstr:"..(demo.passo * 12), 34, 109, 6)
  end

  -- rodape de controle
  rectfill(0, 119, 127, 127, 1)
  local st_txt = demo.tocando and "z:pausa" or "z:play "
  print(st_txt, 2, 121, demo.tocando and 11 or 10)
  print("<>:passo", 42, 121, 7)
  print("r:ini", 96, 121, 6)
end

-- ==========================================
-- TELA 3: SANDBOX INTERATIVO + TELEMETRIA
-- ==========================================
function aplicar_celula(gx, gy, valor)
  if gy >= 1 and gy <= #mapa and gx >= 1 and gx <= #mapa[1] then
    if mapa[gy][gx] != valor then
      mapa[gy][gx] = valor
      resolver_csp()
    end
  end
end

function atualizar_tela3(tecla_r, tecla_c)
  local ox, oy = 16, 10
  local mw, mh = #mapa[1], #mapa

  -- reset mapa (tecla r ou clique em r:rst)
  if tecla_r or (demo.clicou_esq and demo.my >= 119 and demo.mx >= 60 and demo.mx < 94) then
    copiar_mapa_padrao()
    resolver_csp()
    return
  end

  -- limpar mapa (tecla c ou clique em c:limp)
  if tecla_c or (demo.clicou_esq and demo.my >= 119 and demo.mx >= 94) then
    limpar_mapa()
    resolver_csp()
    return
  end

  -- navegacao por teclado na grade
  if (btnp(0)) demo.cx = max(1, demo.cx - 1)
  if (btnp(1)) demo.cx = min(mw, demo.cx + 1)
  if (btnp(2)) demo.cy = max(1, demo.cy - 1)
  if (btnp(3)) demo.cy = min(mh, demo.cy + 1)

  -- z alterna terra/ar no cursor do teclado
  if btnp(4) then
    local novo = mapa[demo.cy][demo.cx] == 1 and 0 or 1
    aplicar_celula(demo.cx, demo.cy, novo)
  end

  -- edicao com mouse (clique + arraste)
  local mx_grid = flr((demo.mx - ox) / 8) + 1
  local my_grid = flr((demo.my - oy) / 8) + 1
  local no_mapa = mx_grid >= 1 and mx_grid <= mw and my_grid >= 1 and my_grid <= mh

  if no_mapa then
    -- sincroniza cursor visual quando o mouse entra no mapa
    if demo.mb_esq or demo.mb_dir then
      demo.cx = mx_grid
      demo.cy = my_grid
    end
    if demo.clicou_esq then
      demo.pintando = mapa[my_grid][mx_grid] == 1 and 0 or 1
      aplicar_celula(mx_grid, my_grid, demo.pintando)
    elseif demo.mb_esq and demo.pintando != nil then
      aplicar_celula(mx_grid, my_grid, demo.pintando)
    elseif demo.mb_dir then
      aplicar_celula(mx_grid, my_grid, 0)
    end
  end

  if not demo.mb_esq then
    demo.pintando = nil
  end
end

function desenhar_tela3()
  local ox, oy = 16, 10
  desenhar_mapa_cache(ox, oy, 3, nil)

  -- grade sutil sobre o ceu para facilitar cliques
  for y = 0, #mapa - 1 do
    for x = 0, #mapa[1] - 1 do
      if mapa[y + 1][x + 1] == 0 then
        pset(ox + x * 8 + 3, oy + y * 8 + 3, 13)
      end
    end
  end

  -- cursor na celula selecionada (mouse se estiver no mapa, senao teclado)
  local hgx = flr((demo.mx - ox) / 8) + 1
  local hgy = flr((demo.my - oy) / 8) + 1
  local cx, cy = demo.cx, demo.cy
  if hgx >= 1 and hgx <= #mapa[1] and hgy >= 1 and hgy <= #mapa then
    cx, cy = hgx, hgy
  end
  local rx = ox + (cx - 1) * 8
  local ry = oy + (cy - 1) * 8
  rect(rx, ry, rx + 7, ry + 7, 10)

  -- painel de telemetria em tempo real (y = 75..118)
  rectfill(0, 75, 127, 118, 0)
  line(0, 75, 127, 75, 13)

  -- linha 1: ram lua (stat 0) e economia de rom
  local ram_kb = stat(0)
  print("ram:"..fmt1(ram_kb).."k/2048k", 2, 77, 12)
  print("rom:160b(-89%)", 70, 77, 11)

  -- linha 2: cpu frame (stat 1) + barra + fps (stat 7)
  local cpu = demo.cpu_suave
  print("cpu:"..fmt1(cpu).."%", 2, 85, 7)
  -- barra de cpu (x=42..88, largura 46px)
  rect(42, 85, 88, 89, 13)
  local bw = min(44, flr((cpu / 100) * 44))
  local cor_cpu = cpu < 50 and 11 or (cpu < 80 and 10 or 8)
  if (bw > 0) rectfill(43, 86, 43 + bw, 88, cor_cpu)
  print("fps:"..stat(7), 94, 85, 11)

  -- linha 3: custo do ultimo solve csp
  print("solve:"..fmt1(metricas.solve_cpu).."%fr", 2, 93, 10)
  print("runs:"..metricas.solve_count, 74, 93, 6)

  -- linha 4: contadores csp ativos
  print("blk:"..metricas.blocos, 2, 101, 7)
  print("sspr:"..metricas.recortes, 38, 101, 11)
  print("cstr:"..metricas.regras, 80, 101, 9)

  -- linha 5: total de chamadas de desenho (spr base + sspr recortes)
  local draws = metricas.blocos + metricas.recortes
  print("draw calls:"..draws.." (spr+sspr)", 2, 109, 6)

  -- rodape de controle (tambem clicavel)
  rectfill(0, 119, 127, 127, 1)
  print("click/z:edit", 2, 121, 10)
  print("r:rst", 64, 121, 7)
  print("c:limp", 96, 121, 8)
end

-- ==========================================
-- BARRA SUPERIOR DE ABAS E CURSOR DO MOUSE
-- ==========================================
function desenhar_abas()
  rectfill(0, 0, 127, 8, 1)
  line(0, 8, 127, 8, 13)

  local abas = {
    {0,  41,  " 1:rom "},
    {42, 84,  " 2:csp "},
    {85, 127, " 3:live"}
  }
  for i = 1, 3 do
    local a = abas[i]
    if demo.tela == i then
      rectfill(a[1], 0, a[2], 7, 12)
      print(a[3], a[1] + 6, 2, 0)
    else
      print(a[3], a[1] + 6, 2, 6)
    end
    if (i < 3) line(a[2], 0, a[2], 7, 13)
  end
end

function desenhar_mouse()
  local x, y = demo.mx, demo.my
  -- cursor classico estilo editor do pico-8 (6x9, zero sprites, zero alocacao)
  -- contorno preto
  line(x, y, x, y + 6, 0)
  line(x + 1, y, x + 5, y + 4, 0)
  line(x + 3, y + 5, x + 5, y + 5, 0)
  pset(x + 1, y + 6, 0)
  pset(x + 4, y + 6, 0)
  pset(x + 2, y + 7, 0)
  pset(x + 4, y + 7, 0)
  pset(x + 3, y + 8, 0)
  -- brilho branco na borda esquerda
  line(x + 1, y + 1, x + 1, y + 5, 7)
  -- corpo vermelho classico do pico-8 + cauda
  line(x + 2, y + 2, x + 2, y + 6, 7)
  line(x + 3, y + 3, x + 3, y + 4, 7)
  pset(x + 4, y + 4, 7)
  line(x + 3, y + 6, x + 3, y + 7, 7)
end

function desenhar_demo()
  cls(1)
  if demo.tela == 1 then
    desenhar_tela1()
  elseif demo.tela == 2 then
    desenhar_tela2()
  else
    desenhar_tela3()
  end
  desenhar_abas()
  desenhar_mouse()
end
