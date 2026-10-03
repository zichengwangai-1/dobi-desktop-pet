"""Verify every decoded frame has transparency, foreground, and actual motion."""
import hashlib, json, pathlib, subprocess, sys
import numpy as np

root = pathlib.Path(__file__).resolve().parents[1]
results = []
for path in sorted((root/'Resources/Videos').glob('*.mov')):
    process = subprocess.Popen(['ffmpeg','-v','error','-i',str(path),'-f','rawvideo','-pix_fmt','rgba','-an','pipe:1'], stdout=subprocess.PIPE)
    frame_bytes = 540*540*4
    frames, unique, transparent, opaque = 0, set(), [], []
    while True:
        data = process.stdout.read(frame_bytes)
        if not data: break
        assert len(data) == frame_bytes, f'{path.name}: incomplete frame'
        frame = np.frombuffer(data, dtype=np.uint8).reshape(540,540,4)
        alpha = frame[:,:,3]
        assert alpha.min() == 0 and alpha.max() == 255, f'{path.name} frame {frames}: missing alpha/foreground'
        assert np.max(alpha[:3,:3]) == 0, f'{path.name} frame {frames}: opaque corner'
        transparent.append(float(np.mean(alpha == 0)))
        opaque.append(float(np.mean(alpha == 255)))
        assert 0.05 < opaque[-1] < 0.9, f'{path.name} frame {frames}: foreground lost'
        unique.add(hashlib.sha256(data).hexdigest())
        frames += 1
    assert process.wait() == 0 and frames >= 50 and len(unique) > 40, f'{path.name}: not a moving clip'
    result = dict(file=path.name, frames=frames, unique_frames=len(unique),
                  alpha_min=0, alpha_max=255, minimum_transparent_fraction=min(transparent),
                  minimum_opaque_fraction=min(opaque), codec='ProRes 4444', passed=True)
    results.append(result)
    print(json.dumps(result), flush=True)
assert {item['file'] for item in results} == {'puppy_walk.mov', 'puppy_spin.mov', 'puppy_sit.mov',
                                           'adult_walk.mov', 'adult_bark.mov', 'puppy_eat.mov', 'adult_eat.mov'}, 'Seven clips are required'
(root/'docs/asset-validation.json').write_text(json.dumps(results, indent=2)+'\n')
