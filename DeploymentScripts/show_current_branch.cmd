echo off

for /D %%f in (*) do (
echo %%f
cd %%f
git branch --show-current
echo -
cd ..
)

