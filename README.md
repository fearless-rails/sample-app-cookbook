# sample-app-cookbook

Provisions a server for the sample app included in [Fearless Rails Deployment](https://railsdeploymentbook.com).

## Supported Platforms

Ubuntu 12.04 LTS

## Usage

### sample-app::default

Include `sample-app` in your node's `run_list`:

```json
{
  "run_list": [
    "recipe[sample-app::default]"
  ]
}
```

## Contributing

1. Fork the repository on Github
2. Create a named feature branch (i.e. `add-new-recipe`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request

## License and Authors

Author:: Zachary Danger Campbell (<zacharydangercampbell@gmail.com>)
