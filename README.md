# FranceScript 🇫🇷

Un langage de programmation moderne avec des mots-clés français qui se compile vers Nim et génère des exécutables natifs performants.

## À propos

FranceScript est un langage de programmation conçu pour les développeurs francophones qui souhaitent coder dans leur langue maternelle. Il combine la simplicité syntaxique du français avec la performance du langage Nim, permettant de créer des applications natives rapides et efficaces.

### Caractéristiques

- **Syntaxe française** : Utilisez des mots-clés comme `fonction`, `variable`, `classe`, `si`, `sinon`, etc.
- **Performance native** : Compilation vers Nim puis vers des exécutables natifs
- **Orienté objet** : Support complet des classes, constructeurs et méthodes
- **Développement web** : Serveur HTTP intégré avec système de routage
- **Multiplateforme** : Compatible macOS, Windows et Linux
- **Interopérabilité Nim** : Intégration directe de code Nim avec les blocs `@nim`

## Installation

### Prérequis

1. **Nim** (version 2.0 ou supérieure) - [Installation de Nim](https://nim-lang.org/install.html)

### Installation du projet

```bash
# Cloner le dépôt
git clone https://github.com/FranceScript/FranceScript.git
cd FranceScript

# Installer les dépendances et construire le projet
nimble install_local
```

## Utilisation rapide

### 1. Écrire votre premier programme

Créez un fichier `hello.fr` :

```francescript
ecrire("Bonjour le monde !")
```

### 2. Compiler un binaire natif

```bash
francescript hello.fr
```

## Syntaxe du langage

### Variables et types

```francescript
variable nom = "Alice"
variable age = 25
variable actif = vrai
```

### Fonctions

```francescript
fonction saluer(nom) {
    retourner "Bonjour " + nom + " !"
}

fonction calculer(a, b) {
    retourner a + b
}
```

### Classes et objets

```francescript
classe Personne ouvrir
    constructeur(nom, age) ouvrir
        ceci->nom egal nom
        ceci->age egal age
    refermer
    
    fonction sePresenter() ouvrir
        retourner "Je suis " + cette->nom + ", j'ai " + ceci->age + " ans"
    refermer
refermer

variable alice egal nouveau Personne("Alice", 30)
ecrire(alice->sePresenter())
```

## Tâches Nimble

- `nimble test` - Lancer les tests
- `nimble build` - Construire le transpileur
- `nimble install_local` - Installer le binaire `francescript` localement

## Exemples

Consultez le dossier `examples/` pour des exemples complets :

- `console_simple.fr` - Exemple d'entrées/sorties console
- `web_simple.fr` - Serveur web avec routage

## Architecture du projet

```
francescript/
├── src/
│   ├── main.nim       # Point d'entrée du transpileur
│   ├── lexer.nim      # Analyseur lexical
│   ├── parser.nim     # Analyseur syntaxique
│   ├─��� codegen.nim    # Générateur de code
│   └── stdlib/        # Bibliothèque standard
│       ├── console.nim
│       ├── conversion.nim
│       └── web_server.nim
├── examples/          # Exemples de code
└── francescript.nimble # Configuration du projet
```

## Contributions

Les contributions sont les bienvenues ! Voici comment contribuer :

1. Fork le projet
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/ma-fonctionnalite`)
3. Committez vos changements (`git commit -am 'Ajouter ma fonctionnalité'`)
4. Pushez vers la branche (`git push origin feature/ma-fonctionnalité`)
5. Ouvrez une Pull Request

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## Remerciements

- Équipe Nim pour le formidable langage de compilation cible

<br>

## **FranceScript** - Programmez en français, compilez en natif ! 🚀

> *Évidemment, ce langage est un projet humoristique et n'est pas destiné à un usage sérieux. Il est conçu pour être amusant et démontrer la flexibilité de Nim !*