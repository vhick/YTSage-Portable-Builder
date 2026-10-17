using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

// Community launcher. Requires .NET Framework 4.x (included with supported Windows 10/11).
// Does not change global environment variables, registry values or the user's PATH.
static class YTSagePortable
{
    // Windows CommandLineToArgvW-compatible quoting (including trailing slashes).
    static string QuoteArgument(string argument)
    {
        if (argument.Length > 0 && argument.IndexOfAny(new char[] {' ', '\t', '\n', '\v', '"'}) == -1)
            return argument;
        var b = new StringBuilder("\"");
        int backslashes = 0;
        foreach (char c in argument)
        {
            if (c == '\\') { backslashes++; continue; }
            if (c == '"')
            {
                b.Append('\\', backslashes * 2 + 1);
                b.Append('"');
                backslashes = 0;
                continue;
            }
            b.Append('\\', backslashes);
            backslashes = 0;
            b.Append(c);
        }
        b.Append('\\', backslashes * 2);
        b.Append('"');
        return b.ToString();
    }

    [STAThread]
    static int Main(string[] args)
    {
        string root = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string app = Path.Combine(root, @"App\YTSage");
        string exe = Path.Combine(app, "YTSage.exe");
        string data = Path.Combine(root, @"Data\YTSage");
        string temp = Path.Combine(root, @"Data\Temp");
        try
        {
            if (!File.Exists(exe))
            {
                MessageBox.Show("Missing App\\YTSage\\YTSage.exe. Re-extract the complete package.",
                                "YTSage Portable", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 2;
            }
            Directory.CreateDirectory(data);
            Directory.CreateDirectory(temp);
            Directory.CreateDirectory(Path.Combine(root, @"Data\DenoCache"));
            Directory.CreateDirectory(Path.Combine(root, @"Data\Cache"));
            Directory.CreateDirectory(Path.Combine(root, @"Data\yt-dlp-config"));

            var psi = new ProcessStartInfo(exe);
            psi.UseShellExecute = false;
            psi.WorkingDirectory = app;
            psi.EnvironmentVariables["YTSAGE_PORTABLE_MODE"] = "1";
            psi.EnvironmentVariables["YTSAGE_DATA_DIR"] = data;
            psi.EnvironmentVariables["YTSAGE_FFMPEG_DIR"] = app;
            psi.EnvironmentVariables["DENO_DIR"] = Path.Combine(root, @"Data\DenoCache");
            psi.EnvironmentVariables["XDG_CACHE_HOME"] = Path.Combine(root, @"Data\Cache");
            psi.EnvironmentVariables["XDG_CONFIG_HOME"] = Path.Combine(root, @"Data\yt-dlp-config");
            psi.EnvironmentVariables["TEMP"] = temp;
            psi.EnvironmentVariables["TMP"] = temp;
            psi.EnvironmentVariables["PATH"] = app + ";" + Path.Combine(data, "bin") + ";" +
                                              psi.EnvironmentVariables["PATH"];
            var commandLine = new StringBuilder();
            foreach (string arg in args)
            {
                if (commandLine.Length > 0) commandLine.Append(" ");
                commandLine.Append(QuoteArgument(arg));
            }
            psi.Arguments = commandLine.ToString();
            using (var proc = Process.Start(psi))
            {
                if (proc == null) return 3;
                proc.WaitForExit();
                return proc.ExitCode;
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.ToString(), "YTSage Portable", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        // Do not purge portable TEMP: an interrupted run may need recovery files.
    }
}
