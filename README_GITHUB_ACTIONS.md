# Compilação automática do APK

O projeto já contém um workflow do GitHub Actions em `.github/workflows/build-apk.yml`.

## Como usar pelo celular

1. Crie uma conta no GitHub.
2. Crie um repositório, por exemplo `splitrunner`.
3. Envie todos os arquivos deste projeto para o repositório.
4. Abra a aba **Actions**.
5. Execute **Build SplitRunner APK** com **Run workflow**, ou faça um push na branch `main`.
6. Quando terminar, abra a execução concluída e baixe o artefato **SplitRunner-APK**.
7. Dentro dele estará `app-release.apk`.

Não é necessário instalar Flutter no celular.
