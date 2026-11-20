-- ==========================================
-- FUNCOES DO SOLVER CSP
-- ==========================================

-- retorna 1 se tiver terra, 0 se for ar ou fora da matriz
function get_tile(x, y)
  if y < 1 or y > #mapa or x < 1 or x > #mapa[1] then
    return 0
  end
  return mapa[y][x]
end

-- auxiliar para juntar nomes de regras disparadas (ex: "n s")
function juntar_tags(lista_tags)
  if (#lista_tags == 0) return "-"
  local s = lista_tags[1]
  for i = 2, #lista_tags do
    s = s.." "..lista_tags[i]
  end
  return s
end

function resolver_csp()
  local cpu_ini = stat(1)
  cache_grama = {}
  local total_rec = 0

  for y = 1, #mapa do
    for x = 1, #mapa[y] do
      if mapa[y][x] == 1 then
        -- coordenadas de tela do pico-8 comecam em 0
        local gx = x - 1
        local gy = y - 1

        -- avalia os 8 vizinhos
        local n  = get_tile(x, y-1)
        local s  = get_tile(x, y+1)
        local o  = get_tile(x-1, y)
        local l  = get_tile(x+1, y)
        local no = get_tile(x-1, y-1)
        local ne = get_tile(x+1, y-1)
        local so = get_tile(x-1, y+1)
        local se = get_tile(x+1, y+1)

        -- lista cumulativa de recortes para este bloco
        local lista = {}
        local t1, t2, t3 = {}, {}, {}

        -- ------------------------------------------------
        -- CAMADA 1: BORDAS RETAS (Quando falta cardeal)
        -- ------------------------------------------------
        if n == 0 then add(lista, pecas.top_edge)    add(t1, "n") end
        if s == 0 then add(lista, pecas.bottom_edge) add(t1, "s") end
        if o == 0 then add(lista, pecas.left_edge)   add(t1, "o") end
        if l == 0 then add(lista, pecas.right_edge)  add(t1, "l") end

        -- ------------------------------------------------
        -- CAMADA 2: QUINAS INTERNAS (Sanitizacao aplicada!)
        -- So desenha se os 2 cardeais adjacentes forem terra (1),
        -- mas a diagonal entre eles estiver aberta (0).
        -- ------------------------------------------------
        if n == 1 and o == 1 and no == 0 then add(lista, pecas.tl_in) add(t2, "no") end
        if n == 1 and l == 1 and ne == 0 then add(lista, pecas.tr_in) add(t2, "ne") end
        if s == 1 and o == 1 and so == 0 then add(lista, pecas.bl_in) add(t2, "so") end
        if s == 1 and l == 1 and se == 0 then add(lista, pecas.br_in) add(t2, "se") end

        -- ------------------------------------------------
        -- CAMADA 3: QUINAS EXTERNAS (Sobreposicao final)
        -- Desenhadas por ultimo para dar acabamento por cima
        -- da juncao de duas bordas retas!
        -- ------------------------------------------------
        if n == 0 and o == 0 then add(lista, pecas.tl_out) add(t3, "no") end
        if n == 0 and l == 0 then add(lista, pecas.tr_out) add(t3, "ne") end
        if s == 0 and o == 0 then add(lista, pecas.bl_out) add(t3, "so") end
        if s == 0 and l == 0 then add(lista, pecas.br_out) add(t3, "se") end

        total_rec += #lista

        -- salva o bloco no cache + metadados p/ inspecao passo a passo
        add(cache_grama, {
          x = gx,
          y = gy,
          recortes = lista,
          viz = {
            no, n, ne,
            o,  1, l,
            so, s, se
          },
          c1 = juntar_tags(t1),
          c2 = juntar_tags(t2),
          c3 = juntar_tags(t3)
        })
      end
    end
  end

  local cpu_fim = stat(1)
  metricas.blocos = #cache_grama
  metricas.recortes = total_rec
  metricas.regras = #cache_grama * 12
  metricas.solve_cpu = max(0, (cpu_fim - cpu_ini) * 100)
  metricas.solve_count += 1
end
