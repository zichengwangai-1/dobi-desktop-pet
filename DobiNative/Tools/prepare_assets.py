"""Create real ProRes 4444 alpha videos from the user's black-backdrop clips."""
import argparse, pathlib, subprocess, shutil, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / '杜宾：小狗动作画面' / '杜宾'
OUTPUT = ROOT / 'Resources' / 'Videos'
CLIPS = {
    'puppy_walk': '幼年期：左右散步.mov',
    'puppy_spin': '幼年期：转圈.mov',
    'puppy_sit': '幼年期：坐下.mov',
    'adult_walk': '成年期：左右散步.mov',
    'adult_bark': '成年期：犬吠.mov',
    'puppy_eat': '幼年期：吃饭.mp4',
    'adult_eat': '成年期：吃饭.mov',
}
parser = argparse.ArgumentParser()
parser.add_argument('--only', nargs='+', choices=list(CLIPS))
selected = parser.parse_args().only or list(CLIPS)
ffmpeg = shutil.which('ffmpeg')
if not ffmpeg:
    sys.exit('ffmpeg is required only to prepare assets, not to run the app.')
tool = ROOT / '.build' / 'segment'
tool.parent.mkdir(exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'swiftc', '-O', '-module-cache-path', '/tmp/dobi-swift-cache',
                str(ROOT/'Tools/Segment.swift'), '-o', str(tool)], check=True)
for name, source in CLIPS.items():
    if name not in selected: continue
    # Loop only the head-down eating section, not the stand-up intro/outro.
    eating_sections = {'puppy_eat': ('0.9', '1.9'), 'adult_eat': ('1.1', '2.3')}
    trim = ['-ss', eating_sections[name][0], '-t', eating_sections[name][1]] if name in eating_sections else []
    decode = subprocess.Popen([ffmpeg, '-v','error',*trim,'-i',str(SOURCE/source),'-vf','fps=30,scale=540:540',
                               '-f','rawvideo','-pix_fmt','rgb24','-an','pipe:1'], stdout=subprocess.PIPE)
    segmentation_options = ['--preserve-color-details'] if name in eating_sections else []
    cutout = subprocess.Popen([str(tool), *segmentation_options], stdin=decode.stdout, stdout=subprocess.PIPE)
    decode.stdout.close()
    encode = subprocess.run([ffmpeg,'-v','error','-y','-f','rawvideo','-pix_fmt','rgba','-s','540x540',
                             '-r','30','-i','pipe:0','-an','-c:v','prores_ks','-profile:v','4',
                             '-pix_fmt','yuva444p10le','-alpha_bits','8',str(OUTPUT/(name+'.mov'))], stdin=cutout.stdout)
    cutout.stdout.close()
    if encode.returncode or cutout.wait() or decode.wait():
        sys.exit('Asset preparation failed: '+name)
    print('Prepared '+name, flush=True)
print('Alpha videos ready.', flush=True)
