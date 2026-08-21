import matplotlib.pyplot as plt

print("=" * 46)
print("  GPS -> PLANO CARTESIANO")
print("  Latitude  = eixo Y (norte-sul / vertical)")
print("  Longitude = eixo X (leste-oeste / horizontal)")
print("=" * 46)

pontos = []
n = int(input("\nQuantos pontos voce quer colocar no mapa? "))

for i in range(n):
    print(f"\n--- Ponto {i+1} ---")
    lat = float(input("Latitude  (Y, ex: -23.55): "))
    lon = float(input("Longitude (X, ex: -46.63): "))
    pontos.append((lon, lat))  # (X, Y)

# ----- monta o grafico -----
fig, ax = plt.subplots(figsize=(10, 8))

ax.set_title("Seus lugares no Plano Cartesiano (GPS)\nX = Longitude | Y = Latitude", fontsize=13, fontweight="bold")

# eixos
ax.axhline(0, color="black", linewidth=1.5)          # eixo X
ax.axvline(0, color="red", linewidth=5, alpha=0.25)  # eixo Y destacado
ax.text(0.02, 0.98, "EIXO Y\nX = 0", transform=ax.transAxes,
        fontsize=10, color="red", fontweight="bold", va="top")

# pontos
xs = [p[0] for p in pontos]
ys = [p[1] for p in pontos]
ax.plot(xs, ys, "o-", color="tab:blue", linewidth=1.5, markersize=9, zorder=5, label="Seus pontos")

for i, (x, y) in enumerate(pontos):
    ax.annotate(f"({x:.2f}, {y:.2f})", (x, y), textcoords="offset points", xytext=(8, 8), fontsize=9)

# cruzamento com o eixo Y (se alguma linha passar por ele)
if len(pontos) >= 2:
    for j in range(len(pontos) - 1):
        x1, y1 = pontos[j]
        x2, y2 = pontos[j + 1]
        if x1 * x2 <= 0:  # mudou de lado do eixo Y -> cruza o eixo
            t = x1 / (x1 - x2)
            yc = y1 + t * (y2 - y1)
            ax.plot(0, yc, "o", color="green", markersize=12, zorder=6)
            ax.annotate(f"Cruza o eixo Y em\n(0, {yc:.2f})", (0, yc),
                        xytext=(15, -18), fontsize=9, color="darkgreen",
                        arrowprops=dict(arrowstyle="->", color="darkgreen"))

ax.axhline(0, color="black", linewidth=1.5)
ax.grid(True, linestyle="--", alpha=0.4)
ax.set_xlabel("Longitude (X)")
ax.set_ylabel("Latitude (Y)")
ax.legend(loc="best")

# margens automaticas
margem_x = max(abs(max(xs)), abs(min(xs)), 1) * 1.2
margem_y = max(abs(max(ys)), abs(min(ys)), 1) * 1.2
ax.set_xlim(-margem_x, margem_x)
ax.set_ylim(-margem_y, margem_y)
ax.set_aspect("equal")

plt.tight_layout()
plt.savefig("/home/edcley/Documentos/plantauto_peeex/meus_pontos_gps.png", dpi=150)
print("\nFigura salva em: Documentos/plantauto_peeex/meus_pontos_gps.png")
plt.show()
