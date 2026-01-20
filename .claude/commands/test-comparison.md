# Run Comparison Tests

Run the comparison test suite that compares uwotmit against the original uwot package.

```bash
cd /Users/rmsharp/Documents/R_packages/uwotmit && Rscript -e "testthat::test_file('tests/testthat/test_comparison_uwot.R')"
```

After running, report whether all comparison tests passed and highlight any differences found between uwotmit and uwot.
