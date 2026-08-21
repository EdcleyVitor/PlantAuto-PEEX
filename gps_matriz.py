import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import FancyArrowPatch

# =========================================================
# SIMULAÇÃO: duas trajetórias no GPS que se cruzam no 8º s
# Trajetória 1 (azul):  Y = 2t + 1
# Trajetória 2 (laranja): Y = -t + 25
# Ponto de encontro: t = 8, Y = 17  ->  (8, 17)
# =========================================================

def equacao1(t):
    return 2 * t + 1

def equacao2(t):
    return -t + 25

t_vals = np.linspace(0, 12, 200)

# ----- resolvendo o sistema (por matrizes) -----
# Matriz A | vetor b
#  [ 2  -1 ] [ t ]   [ 24 ]
#  [ 1   1 ] [ y ] = [ 26 ]
A = np.array([[2, -1],
              [1,  1]])
b = np.array([24, 26])

sol = np.linalg.solve(A, b)          # t = 8, y = 17
t_enc, y_enc = sol[0], sol[1]

# ----- figura principal: plano cartesiano -----
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))

# ---------- GRÁFICO 1: plano cartesiano ----------
ax1.set_title("Plano Cartesiano - GPS\nTrajetórias e cruzamento", fontsize=13, fontweight="bold")

# linhas da grade
ax1.grid(True, linestyle="--", alpha=0.4)

# eixos X e Y (coordenadas cartesianas)
ax1.axhline(0, color="black", linewidth=1.5)   # eixo X
ax1.axvline(0, color="black", linewidth=1.5)   # eixo Y

# destaque do eixo Y (sua parte!)
ax1.axvline(0, color="red", linewidth=5, alpha=0.25, label="Eixo Y (X = 0)")
ax1.text(0.4, 19.5, "EIXO Y\n(vertical, X = 0)", fontsize=10, color="red", fontweight="bold")

# as duas trajetórias
ax1.plot(t_vals, [equacao1(t) for t in t_vals], color="tab:blue", linewidth=2.5, label="Traj. 1: Y = 2t + 1")
ax1.plot(t_vals, [equacao2(t) for t in t_vals], color="tab:orange", linewidth=2.5, label="Traj. 2: Y = -t + 25")

# ponto de cruzamento
ax1.plot(t_enc, y_enc, "o", color="green", markersize=12, zorder=5, label=f"Cruzamento ({t_enc:.0f}, {y_enc:.0f})")
ax1.annotate(f"ENCONTRO\n(8, 17)", xy=(t_enc, y_enc), xytext=(4.5, 21),
             fontsize=11, fontweight="bold", color="darkgreen",
             arrowprops=dict(arrowstyle="->", color="darkgreen"))

# setas indicando X e Y (orientação dos eixos)
ax1.annotate("X (horizontal)", xy=(12, 0), xytext=(9, -4), fontsize=10,
             arrowprops=dict(arrowstyle="->", color="black"))
ax1.annotate("Y (vertical)", xy=(0, 25), xytext=(-4, 24), fontsize=10,
             arrowprops=dict(arrowstyle="->", color="black"))

ax1.set_xlim(-1, 13)
ax1.set_ylim(-5, 27)
ax1.set_xlabel("tempo (s)")
ax1.set_ylabel("posição Y")
ax1.legend(loc="lower right", fontsize=9)

# ---------- GRÁFICO 2: a matriz do sistema ----------
ax2.axis("off")
ax2.set_title("O sistema vira uma MATRIZ", fontsize=13, fontweight="bold")

# desenha colchetes da matriz
ax2.text(0.5, 0.78, "Duas equações:", fontsize=11, ha="center", fontweight="bold")
ax2.text(0.5, 0.68, " 2t - y = 24\n   t + y = 26", fontsize=12, ha="center",
         family="monospace", bbox=dict(boxstyle="round", facecolor="lightyellow"))

ax2.text(0.5, 0.48, "Na forma de matriz (A · x = b):", fontsize=11, ha="center", fontweight="bold")

# linha da matriz
ax2.text(0.20, 0.34, "[ 2  -1 ]", fontsize=14, ha="center", family="monospace")
ax2.text(0.20, 0.18, "[ 1   1 ]", fontsize=14, ha="center", family="monospace")
ax2.plot([0.08, 0.08], [0.14, 0.38], color="black", linewidth=2)
ax2.plot([0.36, 0.36], [0.14, 0.38], color="black", linewidth=2)
ax2.text(0.20, 0.02, "matriz A", fontsize=10, ha="center", color="gray")

ax2.text(0.45, 0.26, "·", fontsize=16, ha="center")
ax2.text(0.52, 0.31, "[t]", fontsize=14, ha="center", family="monospace")
ax2.text(0.52, 0.15, "[y]", fontsize=14, ha="center", family="monospace")
ax2.plot([0.44, 0.44], [0.11, 0.35], color="black", linewidth=2)
ax2.plot([0.62, 0.62], [0.11, 0.35], color="black", linewidth=2)
ax2.text(0.52, 0.02, "vetor x", fontsize=10, ha="center", color="gray")

ax2.text(0.72, 0.26, "=", fontsize=16, ha="center")
ax2.text(0.81, 0.31, "[24]", fontsize=14, ha="center", family="monospace")
ax2.text(0.81, 0.15, "[26]", fontsize=14, ha="center", family="monospace")
ax2.plot([0.73, 0.73], [0.11, 0.35], color="black", linewidth=2)
ax2.plot([0.91, 0.91], [0.11, 0.35], color="black", linewidth=2)
ax2.text(0.81, 0.02, "vetor b", fontsize=10, ha="center", color="gray")

ax2.text(0.5, -0.12, f"Resolvendo:  t = {t_enc:.1f} s   e   y = {y_enc:.1f}\n"
                     "O sistema 'encaixa' no 8º segundo = o cruzamento!", fontsize=12,
         ha="center", fontweight="bold", color="darkgreen",
         bbox=dict(boxstyle="round", facecolor="lightgreen"))

plt.tight_layout()
plt.savefig("/home/edcley/Documentos/plantauto_peeex/gps_matriz.png", dpi=150)
print("Figura salva em: Documentos/plantauto_peeex/gps_matriz.png")
print(f"Cruzamento resolvido por matriz: t = {t_enc:.1f} s, y = {y_enc:.1f}")
plt.show()
