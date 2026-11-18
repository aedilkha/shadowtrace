# viz/

`shadowtrace-3d.html` : carte 3D interactive de l'incident (Three.js), avec rejeu pas à pas de l'attaque.
Ouvre le fichier dans un navigateur : il contient un jeu de données d'exemple. Pour afficher **tes** alertes :

```bash
python3 tools/wazuh_to_3d.py --since 2026-11-20T09:00:00 --out viz/incident.json
```
puis bouton « Charger un JSON » > `viz/incident.json`.
